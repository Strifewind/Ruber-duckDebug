defmodule RuberDuckDebug.Runner do
  @moduledoc "Runs the bounded Python subset interpreter, never eval/exec of submissions."

  def check(code, challenge) do
    python = python_executable()

    path =
      Path.join(
        System.tmp_dir!(),
        "duck-#{Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)}.json"
      )

    if python do
      try do
        File.write!(
          path,
          Jason.encode!(%{code: code, function: challenge["function"], tests: challenge["tests"]})
        )

        script = Application.app_dir(:ruber_duck_debug, "priv/python_runner.py")

        task =
          Task.async(fn ->
            try do
              System.cmd(python, ["-I", script, path], stderr_to_stdout: true)
            rescue
              _ -> {"Python could not start", 1}
            end
          end)

        case Task.yield(task, 8_000) || Task.shutdown(task, :brutal_kill) do
          {:ok, {output, 0}} ->
            case Jason.decode(output) do
              {:ok, %{"error" => error}} -> {:error, error}
              {:ok, %{"results" => _, "passed" => _} = result} -> {:ok, result}
              _ -> {:error, "Python returned an invalid result"}
            end

          _ ->
            {:error, "Python check timed out or could not start"}
        end
      rescue
        _ -> {:error, "Python is unavailable. Set PYTHON_EXECUTABLE to a Python 3 executable."}
      after
        File.rm(path)
      end
    else
      {:error, "Install Python 3 and set PYTHON_EXECUTABLE."}
    end
  end

  defp python_executable do
    configured = System.get_env("PYTHON_EXECUTABLE")
    local = System.get_env("LOCALAPPDATA", "")

    candidates = [
      configured,
      System.find_executable("python3"),
      System.find_executable("python"),
      Path.join(local, "Programs/Python/Python312/python.exe")
    ]

    Enum.find(candidates, fn path ->
      is_binary(path) and not String.contains?(path, "WindowsApps") and File.regular?(path)
    end)
  end

  def validate(challenge) do
    case check(challenge["solution"], challenge) do
      {:ok, %{"passed" => true}} ->
        case check(challenge["code"], challenge) do
          {:ok, %{"passed" => false}} ->
            {:ok, challenge}

          {:ok, %{"passed" => true}} ->
            {:error, "Gemma's starting code had no bug exposed by its tests."}

          {:error, reason} ->
            {:error, "Starting code is outside the supported subset: #{reason}"}
        end

      {:ok, _} ->
        {:error, "Gemma's reference solution failed its own tests."}

      {:error, reason} ->
        {:error, "Reference solution is outside the supported subset: #{reason}"}
    end
  end
end
