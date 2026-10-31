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

- Elixir 1.17 or newer and a compatible Erlang/OTP release (Elixir 1.18 with
  OTP 27 is a known-good combination). Follow the
  [official Elixir installation guide](https://elixir-lang.org/install.html) for
  your operating system, and verify the installed versions before continuing.
- Git, PostgreSQL, and Python 3.12 or newer. Python runs challenge checks on the
  Phoenix server; set `PYTHON_EXECUTABLE` if it is not discoverable on `PATH`.
- Internet access to Hex and GitHub for dependencies and asset downloads.

### Windows

Use PowerShell. Install Git and Python 3.12 with WinGet:

```powershell
winget install --id Git.Git --exact
winget install --id Python.Python.3.12 --exact
```

Install Erlang/OTP and Elixir using the Windows instructions in the
[Elixir installation guide](https://elixir-lang.org/install.html). Install
PostgreSQL using the [Windows installer](https://www.postgresql.org/download/windows/);
remember the password chosen for the `postgres` database user. Open a new
PowerShell window after installing tools, then verify:

```powershell
git --version
elixir --version
mix --version
python --version
psql --version
```

Set the database connection for the current PowerShell session. Enter the
PostgreSQL password when prompted:

```powershell
$env:PGUSER = "postgres"
$env:PGHOST = "localhost"
$env:PGPASSWORD = Read-Host "PostgreSQL password"
```

If Python is not found by the app, set its full path:

```powershell
$env:PYTHON_EXECUTABLE = (Get-Command python).Source
```

If PostgreSQL's `psql` command is not recognized, add its `bin` directory
(typically `C:\Program Files\PostgreSQL\17\bin`) to your `PATH`, or use the
SQL Shell (psql) shortcut installed with PostgreSQL.

### Ubuntu Linux

On Ubuntu 24.04 LTS, install Git, PostgreSQL, and Python:

```sh
sudo apt update
sudo apt install -y git postgresql postgresql-contrib python3
```

Install Erlang/OTP and Elixir using the Linux instructions in the
[Elixir installation guide](https://elixir-lang.org/install.html). Confirm the
Python version is 3.12 or newer; if not, install a supported Python version and
set `PYTHON_EXECUTABLE` to its executable path. Set a password for PostgreSQL's
`postgres` role so the app can connect over localhost:

```sh
sudo -u postgres psql
```

At the `psql` prompt, set the password and exit:

```text
\password postgres
\q
```

Set the connection settings in the terminal used to start the app. The password
prompt does not put the entered value in shell history:

```sh
export PGUSER=postgres
export PGHOST=localhost
read -rsp "PostgreSQL password: " PGPASSWORD; echo
export PGPASSWORD
```

If you installed a separate Python 3.12 executable, select it explicitly:

```sh
export PYTHON_EXECUTABLE="$(command -v python3.12)"
```

Verify the installation:

```sh
git --version
elixir --version
mix --version
python3 --version
psql --version
pg_isready
```

### macOS

Install [Homebrew](https://brew.sh) if needed, then install Erlang/OTP, Elixir,
Git, PostgreSQL, and Python:

```sh
brew install erlang elixir git postgresql@17 python@3.12
brew services start postgresql@17
```

Homebrew's local PostgreSQL setup normally creates a database role matching
your macOS account. Set a password for that role so the app can connect over
localhost:

```sh
psql -d postgres
```

At the `psql` prompt, set the password and exit:

```text
\password
\q
```

Use the role matching your macOS account and enter its password in the app
terminal:

```sh
export PGUSER="$(whoami)"
export PGHOST=localhost
read -rsp "PostgreSQL password: " PGPASSWORD; echo
export PGPASSWORD
export PYTHON_EXECUTABLE="$(command -v python3.12)"
```

If you use a different PostgreSQL role, set `PGUSER` to that role and provide
its password in `PGPASSWORD`. Verify the installation:

```sh
git --version
elixir --version
mix --version
python3.12 --version
psql --version
pg_isready
```

The configured PostgreSQL role must be able to create databases. `mix setup`
creates `ruber_duck_debug_dev`; tests use a separate `ruber_duck_debug_test`
database. Do not commit local credentials.

### Install dependencies and run

In the terminal configured above, change to the repository root and install
dependencies, prepare the database, and build assets:

```sh
mix local.hex --force
mix local.rebar --force
mix setup
```

Start the development server and open <http://localhost:4000>:

```sh
mix phx.server
```

For an interactive console, run `iex -S mix phx.server`. The development
dashboard is available at `/dev/dashboard`, in development only.

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
