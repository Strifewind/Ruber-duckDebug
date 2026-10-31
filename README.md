# Ruber-duckDebug

A cooperative debugging game for three student programmers. Each teammate receives
different information and practices explaining evidence and testing hypotheses.
The duck facilitates with questions rather than revealing private information or
supplying fixes.

## Template

The application is scaffolded with Phoenix 1.8, LiveView, Ecto/PostgreSQL,
Phoenix PubSub, Bandit, and the standard Tailwind/esbuild asset pipeline.
The home LiveView introduces the roles and cycles through public duck questions.
These preview prompts are local to each LiveView, not synchronized between players.

This is an application shell, not a playable game yet: rooms, player identity,
role assignment, private challenge packages, chat, CodeMirror, validation execution,
AI integration, debriefs, and timers are not implemented. No private challenge
materials are loaded or sent to browsers.

## Local setup

### Requirements

- Elixir 1.17 or newer with a compatible Erlang/OTP release (for example,
  Elixir 1.18 with OTP 27).
- PostgreSQL running locally.
- Access to Hex and GitHub for dependencies and asset downloads.

On macOS, install [Homebrew](https://brew.sh) if needed, then install Erlang/OTP
and Elixir:

```sh
brew install erlang elixir
```

Verify the installations:

```sh
erl -noshell -eval 'io:format("OTP ~s~n", [erlang:system_info(otp_release)]), halt().'
elixir --version
mix --version
```

Install PostgreSQL and start it as a background service:

```sh
brew install postgresql@17
brew services start postgresql@17
```

Verify PostgreSQL is running:

```sh
psql --version
pg_isready
```

The local configuration defaults to a PostgreSQL user named `postgres` on
`localhost`. If your local setup uses a different username or connection
settings, set `PGUSER`, `PGPASSWORD`, and `PGHOST` in your shell to match.
The configured user must be able to create databases. `mix setup` creates
`ruber_duck_debug_dev`; tests use a separate `ruber_duck_debug_test` database.
No PostgreSQL password is committed.

From the repository root, install the project dependencies and prepare the
database and assets:

```sh
mix local.hex --force
mix local.rebar --force
mix setup
```

Start the development server:

```sh
mix phx.server
```

Open <http://localhost:4000>. For an interactive console, use `iex -S mix phx.server`.
The development dashboard is available at `/dev/dashboard`, in development only.

Database connections default to user `postgres` on `localhost`. Set `PGUSER`,
`PGPASSWORD`, and `PGHOST` in your shell to match your local PostgreSQL installation.
The configured user must be able to create databases. `mix setup` creates
`ruber_duck_debug_dev`; tests use a separate `ruber_duck_debug_test` database.
No PostgreSQL password is committed.

## Local AI setup (Ollama and Gemma 3)

The planned local model is `gemma3:4b`, served through Ollama. AI integration
is not implemented in the application yet; these steps prepare the local runtime.

On Windows, install Ollama from PowerShell using the command from the
[official Ollama download page](https://ollama.com/download/windows):

```powershell
irm https://ollama.com/install.ps1 | iex
```

Start Ollama, then open a new terminal in VS Code (restart VS Code if `ollama`
is not recognized). Download the model and try an interactive conversation:

```powershell
ollama pull gemma3:4b
ollama run gemma3:4b
```

Enter `/bye` to exit the conversation. Use `ollama list` to confirm the model
is downloaded. See the [Gemma 3 4B model page](https://ollama.com/library/gemma3:4b)
for model details.

## Checks

```sh
mix format --check-formatted
mix test
mix assets.build
mix precommit
```

`mix precommit` compiles with warnings as errors, removes unused dependency locks,
formats, and runs tests. Tests require PostgreSQL; LiveView tests cover the
landing page and public prompt interaction.

## Cooperative model

| Role | Private material | Responsibility |
| --- | --- | --- |
| Driver | Broken code and editor | Explain code, make edits, and request checks |
| Observer | Symptoms, reproduction steps, and check output | Describe expected versus actual behavior |
| Researcher | Documentation and references | Propose hypotheses and experiments |

A round assigns roles, shares observations through text conversation, tests a
hypothesis, and lets the team revise or submit a solution. The full challenge is
revealed only during the debrief; roles then rotate. An optional round timer can
support the team without competitive interruptions.

Future rooms must be coordinated by the server. Each challenge package needs driver
code, observer evidence, researcher references, validation checks, and a root-cause
debrief. Authorize identity, membership, and role server-side before sending any
material. Apply this to LiveView mounts, events, broadcasts, check results,
reconnects, and role changes; never send the whole challenge and hide panels with
CSS. The app must not automatically expose another role's material. Any future
execution of player-submitted code needs an isolated sandbox, not the Phoenix
application process.

## Production configuration

Provide `DATABASE_URL`, `SECRET_KEY_BASE` (generate with `mix phx.gen.secret`),
and `PHX_HOST` through the deployment environment, never committed files.
Set `PHX_SERVER=true` to start the HTTP server in a release; `PORT` defaults to 4000.
Build assets with `MIX_ENV=prod mix assets.deploy`, compile the release, and run
database migrations as part of deployment.

The deterministic development/test signing keys are local-only placeholders.
Production requires its own secret key and database connection. Configure TLS
or a trusted TLS-terminating proxy, HTTPS redirects, and database TLS as appropriate
for your deployment before exposing the app publicly.
