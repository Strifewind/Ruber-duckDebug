defmodule Mix.Tasks.Duck.Smoke do
  use Mix.Task
  @shortdoc "Generate and verify one challenge with the configured Ollama model"
  def run(_args) do
    Mix.Task.run("app.start")
    Mix.shell().info("Requesting a fresh challenge from Ollama (up to 90 seconds)…")

    case RuberDuckDebug.RoundAI.generate(1) do
      {:ok, challenge} -> Mix.shell().info("Verified Gemma challenge: #{challenge["title"]}")
      {:error, reason} -> Mix.raise(reason)
    end
  end
end
