"""Bounded interpreter for the demo's Python subset. Never eval/exec player code.

Only one function, numbers, booleans, lists, comparisons, assignments, if/for,
return, indexing and a small set of pure builtins are supported. No imports,
attributes, arbitrary calls, recursion, I/O, comprehensions or while loops.
"""
import ast
import json
import operator
import sys


class Returned(Exception):
    def __init__(self, value):
        self.value = value


class Interpreter:
    def __init__(self):
        self.steps = 0

    def bound(self, value):
        if isinstance(value, (list, tuple)):
            if len(value) > 256:
                raise ValueError("List limit exceeded")
            for item in value:
                self.bound(item)
        elif isinstance(value, str):
            if len(value) > 1024:
                raise ValueError("String limit exceeded")
        elif isinstance(value, (int, float)):
            if not -1_000_000_000 <= value <= 1_000_000_000:
                raise ValueError("Numeric limit exceeded")
        elif value is not None:
            raise ValueError("Unsupported value")
        return value

    def tick(self):
        self.steps += 1
        if self.steps > 10000:
            raise ValueError("Step limit exceeded")

    def expr(self, node, env):
        self.tick()
        if isinstance(node, ast.Constant):
            return self.bound(node.value)
        if isinstance(node, ast.Name):
            return env[node.id]
        if isinstance(node, (ast.List, ast.Tuple)):
            return self.bound([self.expr(x, env) for x in node.elts])
        if isinstance(node, ast.BinOp):
            a, b = self.expr(node.left, env), self.expr(node.right, env)
            operations = {ast.Add: operator.add, ast.Sub: operator.sub,
                          ast.Mult: operator.mul, ast.Div: operator.truediv,
                          ast.FloorDiv: operator.floordiv, ast.Mod: operator.mod}
            if type(node.op) not in operations:
                raise ValueError("Unsupported arithmetic")
            if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
                raise ValueError("Arithmetic supports numbers only")
            return self.bound(operations[type(node.op)](a, b))
        if isinstance(node, ast.UnaryOp):
            value = self.expr(node.operand, env)
            operations = {ast.USub: operator.neg, ast.UAdd: operator.pos, ast.Not: operator.not_}
            return self.bound(operations[type(node.op)](value))
        if isinstance(node, ast.Compare):
            operations = {ast.Eq: operator.eq, ast.NotEq: operator.ne, ast.Lt: operator.lt,
                          ast.LtE: operator.le, ast.Gt: operator.gt, ast.GtE: operator.ge,
                          ast.In: lambda a, b: a in b, ast.NotIn: lambda a, b: a not in b}
            a = self.expr(node.left, env)
            for op, other in zip(node.ops, node.comparators):
                b = self.expr(other, env)
                if not operations[type(op)](a, b):
                    return False
                a = b
            return True
        if isinstance(node, ast.BoolOp):
            value = None
            for item in node.values:
                value = self.expr(item, env)
                if isinstance(node.op, ast.And) and not value:
                    return value
                if isinstance(node.op, ast.Or) and value:
                    return value
            return value
        if isinstance(node, ast.IfExp):
            return self.expr(node.body if self.expr(node.test, env) else node.orelse, env)
        if isinstance(node, ast.Subscript):
            collection = self.expr(node.value, env)
            if isinstance(node.slice, ast.Slice):
                part = node.slice
                index = slice(*(self.expr(x, env) if x else None
                                for x in [part.lower, part.upper, part.step]))
            else:
                index = self.expr(node.slice, env)
            return self.bound(collection[index])
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
            allowed = {"len": len, "sum": sum, "min": min, "max": max,
                       "abs": abs, "sorted": sorted, "range": range}
            if node.func.id not in allowed:
                raise ValueError("Only len, sum, min, max, abs, sorted, range calls are allowed")
            args = [self.expr(x, env) for x in node.args]
            result = allowed[node.func.id](*args)
            if isinstance(result, range):
                if len(result) > 256:
                    raise ValueError("Range limit exceeded")
                result = list(result)
            return self.bound(result)
        raise ValueError("Unsupported Python feature: " + type(node).__name__)

    def block(self, nodes, env):
        for node in nodes:
            self.tick()
            if isinstance(node, ast.Return):
                raise Returned(self.expr(node.value, env) if node.value else None)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                env[node.targets[0].id] = self.expr(node.value, env)
            elif isinstance(node, ast.AugAssign) and isinstance(node.target, ast.Name):
                env[node.target.id] = self.expr(ast.BinOp(left=node.target, op=node.op, right=node.value), env)
            elif isinstance(node, ast.If):
                self.block(node.body if self.expr(node.test, env) else node.orelse, env)
            elif isinstance(node, ast.For) and isinstance(node.target, ast.Name) and not node.orelse:
                values = self.expr(node.iter, env)
                if not isinstance(values, (list, tuple, str)):
                    raise ValueError("Unsupported iterator")
                for value in values:
                    env[node.target.id] = value
                    self.block(node.body, env)
            elif isinstance(node, ast.Pass):
                pass
            else:
                raise ValueError("Unsupported statement: " + type(node).__name__)

    def run(self, function, args):
        if len(args) != len(function.args.args):
            raise ValueError("Function arguments do not match")
        env = dict(zip([a.arg for a in function.args.args], args))
        self.bound(args)
        try:
            self.block(function.body, env)
        except Returned as result:
            return result.value
        return None


def main(payload):
    code = payload["code"]
    if len(code) > 8000 or len(payload["tests"]) > 20:
        raise ValueError("Challenge size limit exceeded")
    tree = ast.parse(code)
    if len(list(ast.walk(tree))) > 500:
        raise ValueError("Code complexity limit exceeded")
    if len(tree.body) != 1 or not isinstance(tree.body[0], ast.FunctionDef):
        raise ValueError("Define exactly one Python function")
    function = tree.body[0]
    if (function.name != payload["function"] or function.decorator_list or
        function.args.defaults or function.args.kwonlyargs or function.args.posonlyargs or
        function.args.vararg or function.args.kwarg):
        raise ValueError("Use the supplied function signature without decorators or defaults")
    forbidden = (ast.Import, ast.ImportFrom, ast.Attribute, ast.Lambda, ast.While,
                 ast.ClassDef, ast.Global, ast.Nonlocal, ast.With, ast.Try,
                 ast.ListComp, ast.DictComp, ast.SetComp, ast.GeneratorExp)
    if any(isinstance(n, forbidden) for n in ast.walk(tree)):
        raise ValueError("This Python feature is outside the supported challenge subset")
    results = []
    for test in payload["tests"]:
        try:
            actual = Interpreter().run(function, test["args"])
            results.append({"passed": actual == test["expected"], "actual": actual,
                            "expected": test["expected"], "args": test["args"]})
        except Exception as exc:
            results.append({"passed": False, "error": str(exc)[:250],
                            "expected": test["expected"], "args": test["args"]})
    return {"results": results, "passed": all(r["passed"] for r in results)}


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8") as source:
            result = main(json.load(source))
    except Exception as exc:
        result = {"error": str(exc)[:250]}
    print(json.dumps(result, allow_nan=False))
