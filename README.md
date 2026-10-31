# Ruber-duckDebug

A cooperative debugging game for three student programmers. Each teammate receives
different information and practices explaining evidence and testing hypotheses.
The duck facilitates with questions rather than revealing private information or
supplying fixes.

## What is included

The application is scaffolded with Phoenix 1.8, LiveView, Ecto/PostgreSQL,
Phoenix PubSub, Bandit, and the standard Tailwind/esbuild asset pipeline.
The role-selection screens at `/` are previews with prompts local to each LiveView.
The optional playable flow at `/play` provides three-player rooms, private role
materials, a shared notebook, restricted Python checks, and local Ollama integration.
See [LLM and multiplayer integration](docs/llm-comms.md) for gameplay, configuration,
supported Python features, and demo limits.

## Local setup

### Requirements

- Elixir 1.17 or newer with a compatible Erlang/OTP release (for example,
  Elixir 1.18 with OTP 27).
- PostgreSQL running locally.
- Python 3.12 or newer on the Phoenix server's `PATH` for challenge checks. Set
  `PYTHON_EXECUTABLE` if Python is installed elsewhere.
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

The local configuration defaults to the `postgres` user on `localhost`. If your
PostgreSQL setup uses different connection settings, set `PGUSER`, `PGPASSWORD`,
and `PGHOST` in your shell. Avoid committing local credentials.

The configured user must be able to create databases. `mix setup` creates
`ruber_duck_debug_dev`; tests use a separate `ruber_duck_debug_test` database.
No PostgreSQL password is committed.

From the repository root, install dependencies and prepare the database and assets:

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

## Local AI setup (Ollama and Gemma 3)

Ollama is optional. The `/play` flow uses the `gemma3:4b` model for challenge
generation and additional end-of-round reviews; it falls back to curated challenges
when generation is unavailable. Install Ollama using the
[official instructions](https://ollama.com/download), then run:

```sh
ollama pull gemma3:4b
ollama run gemma3:4b
```

Enter `/bye` to exit the interactive chat. Keep Ollama running while playing.
See [LLM and multiplayer integration](docs/llm-comms.md) for environment settings
and the live-model smoke check.

## Checks

```sh
mix format --check-formatted
mix test
mix assets.build
mix precommit
```

`mix precommit` compiles with warnings as errors, removes unused dependency locks,
formats, and runs tests. Tests require PostgreSQL and cover the role previews,
lobby, room authorization and round flow, Python restrictions, and stubbed Ollama
requests. `mix assets.build` uses the project's standard asset pipeline.

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

Room membership, role authorization, turn transitions, and private challenge
materials are enforced server-side. Seat URLs are signed bearer links; share only the
room code, and keep each seat URL private. PubSub broadcasts room-change notifications
rather than challenge contents. Python checks use a restricted interpreter, not a
general-purpose sandbox; see the integration guide for its limits.

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
