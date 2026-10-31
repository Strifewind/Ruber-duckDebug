# Local LLM and multiplayer integration

This is an additive integration on top of main's resources. `/` retains the role
previews and Quackula animation. The new `/play` lobby and `/rooms/:code` routes
provide a playable three-person investigation. They reuse main's layout, theme
tokens, mascot SVG, and talking-beak styles. Database settings, Repo, migrations,
dependency versions/lockfile, and standard build aliases are unchanged.

## Run and play

Follow the main README for Elixir, PostgreSQL, dependency setup, and starting
Phoenix. Additionally, install Python 3.12 or newer for challenge checks. If it is
not on PATH, set `PYTHON_EXECUTABLE` to its full executable path in the terminal
used to start Phoenix. For example, on Windows:

```powershell
winget install --id Python.Python.3.12 --exact --source winget
$env:PYTHON_EXECUTABLE = 'C:\path\to\python.exe'
```

Open `http://localhost:4000/play` or choose **Play with your team** on the home page.
Create a room and share its 20-character code with two teammates. The code is a
96-bit random invite credential; share it only with your team. For a local demo,
three tabs can join independently under different names.

Live roles are assigned by join order (Driver, Observer, Researcher), then rotate
after each round. The role preview at `/` does not reserve a live seat.

- Researcher receives the objective and language documentation, then records a hypothesis.
- Driver receives code and an editor, applies the experiment, and requests checks.
- Observer receives symptoms and check results, explains the evidence, then advances play.
- Failed checks return the turn to Researcher. Passing checks end the round after
  Observer confirms the evidence has been shared.
- The team notebook is shared; players can also use their own voice call.
- The room creator can end an unsolved round. The shared debrief reveals the
  reference solution and recorded actions. The next round resets context and rotates roles.

Keep screens private. Seat URLs contain signed bearer tokens: retain your own URL
for reconnection, but share only the room code. Only the current authorized role's
package is sent to a browser before debrief. PubSub broadcasts change notifications,
not complete challenge data.

## Ollama

Use the main README's Ollama installation instructions, then download the model:

```sh
ollama pull gemma3:4b
ollama run gemma3:4b
```

Enter `/bye` to exit the interactive chat. Keep Ollama running. Players do not need
Ollama installed; the Phoenix server makes the requests. Optional environment settings:

| Variable | Default | Purpose |
| --- | --- | --- |
| `OLLAMA_URL` | `http://localhost:11434` | Server-side Ollama base URL |
| `OLLAMA_MODEL` | `gemma3:4b` | Model identifier |
| `PYTHON_EXECUTABLE` | Discovered from PATH | Python 3 executable |

Run `mix duck.smoke` to request and verify a real model-generated challenge.

`Ollama.chat/2` calls `/api/chat` without streaming and returns tagged results.
Requests have a 3-second connect timeout and 90-second response timeout.
`RoundAI` loads `Context.md` at compilation and builds a new message list for each
round. Generation includes a static worked example, not previous player history.
Private JSON packages undergo local shape validation and Python checks: the
reference must pass every test and the starting code must fail at least one.
Invalid/unavailable generation is announced and falls back to a curated challenge.

AI reviews use the current round's recorded evidence. The last 12 events are sent
with long text shortened to bound context; the full record remains visible in the
shared debrief. Voice conversations are not transcribed or inferred. A deterministic
review appears immediately, and the model's additional review replaces it if ready
before the next round begins. Starting the next round discards pending old results.

## Python checks

The checker parses and interprets a restricted Python AST. It never `eval`s or
`exec`s submissions. It supports one function, ordinary positional arguments,
numbers, booleans, small lists, assignment, return, if/else, for loops, indexing,
slicing, comparisons, boolean expressions, and numeric `+ - * / // %`.
Allowed calls are `len`, `sum`, `min`, `max`, `abs`, `sorted`, and bounded `range`.

Imports, arbitrary calls, attributes, decorators, recursion, comprehensions,
`while`, and I/O are unsupported. Checks have a 10,000-step budget, source limit
of 8 KB, lists/ranges limited to 256 items, and numeric magnitude limited to one
billion. This is a limited interpreter, not a full Python runtime or general-purpose
sandbox. Verification checks agreement with the supplied tests, not a proof of
the model's intended behavior. Unrestricted Python would require an isolated runner.

## Checks and optional Windows workaround

```sh
mix compile --warnings-as-errors
mix test
mix assets.build
```

Tests cover main's existing preview, lobby navigation, membership and role
authorization, private rendered views, complete repair cycles, stale round reset,
restricted Python evaluation, and Ollama HTTP success/failure paths. Ollama is
stubbed in automated tests; only `mix duck.smoke` needs the real model.

Main's `mix assets.build` and development watchers are unchanged. If standalone
Tailwind fails to write into a Windows OneDrive directory with an `EEXIST` error,
the optional `mix duck.assets` task captures its CSS output and writes it through
Elixir, then runs main's configured esbuild profile. This workaround does not change
the shared asset pipeline. Repeat it after CSS changes on affected installations.

## Demo limits

Rooms and reviews are in memory on one Phoenix node. Restarting the server clears
them, and idle rooms expire after one hour. Three seats are required; full rooms
have no replacement/kick flow, so reconnect with the existing seat link or create
a new room. Built-in voice, accounts, persisted rounds, timers, and a full code
editor are not included. The textarea editor supports four-space Tab indentation.
Notebook and round records are bounded. This flow is intended for a small trusted team.
