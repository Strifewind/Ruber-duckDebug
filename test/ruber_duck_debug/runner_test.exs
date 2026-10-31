defmodule RuberDuckDebug.RunnerTest do
  use ExUnit.Case, async: true
  alias RuberDuckDebug.{Challenges, Runner}

  test "all curated challenges have failing starting code and passing reference solutions" do
    for challenge <- Challenges.all() do
      assert {:ok, ^challenge} = Runner.validate(challenge)
    end
  end

  test "alternative correct solutions pass" do
    code =
      "def parcel_total(weights):\n    total = 0\n    for weight in weights:\n        total += weight\n    return total\n"

    assert {:ok, %{"passed" => true}} = Runner.check(code, Challenges.get(1))
  end

  test "imports, decorators, arbitrary calls and oversized ranges are rejected" do
    for code <- [
          "import os\ndef parcel_total(weights):\n    return 0",
          "@print\ndef parcel_total(weights):\n    return 0",
          "def parcel_total(weights):\n    return __import__('os')",
          "def parcel_total(weights):\n    return len(range(1000000000))",
          "def parcel_total(weights):\n    return weights.__class__"
        ] do
      result = Runner.check(code, Challenges.get(1))
      assert match?({:error, _}, result) or match?({:ok, %{"passed" => false}}, result)
    end
  end

  test "nested loops exhaust a bounded step budget" do
    code =
      "def parcel_total(weights):\n    for a in range(256):\n        for b in range(256):\n            pass\n    return 0"

    assert {:ok, %{"passed" => false, "results" => results}} =
             Runner.check(code, Challenges.get(1))

    assert Enum.all?(results, &(&1["error"] == "Step limit exceeded"))
  end
end
