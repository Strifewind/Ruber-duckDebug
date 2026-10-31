defmodule Mix.Tasks.Duck.Assets do
  use Mix.Task
  @shortdoc "Optional OneDrive-compatible asset build; leaves main's asset aliases unchanged"
  def run(args) do
    Mix.Task.run("compile")

    case RuberDuckDebug.Assets.build(args) do
      :ok -> Mix.Task.run("esbuild", ["ruber_duck_debug"])
      {:error, status} -> Mix.raise("Tailwind exited with #{status}")
    end
  end
end
