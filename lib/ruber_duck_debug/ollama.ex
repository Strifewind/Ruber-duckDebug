defmodule RuberDuckDebug.Ollama do
  @moduledoc "Stateless Ollama transport. Callers own and reset round context."

  def chat(messages, opts \\ []) do
    url = System.get_env("OLLAMA_URL", "http://localhost:11434") |> String.trim_trailing("/")
    model = System.get_env("OLLAMA_MODEL", "gemma3:4b")
    timeout = Keyword.get(opts, :timeout, 90_000)

    payload = %{
      model: model,
      messages: messages,
      stream: false,
      options: %{temperature: 0.2, num_predict: 2500, num_ctx: 8192}
    }

    payload = if format = opts[:format], do: Map.put(payload, :format, format), else: payload

    request =
      {String.to_charlist(url <> "/api/chat"), [], ~c"application/json", Jason.encode!(payload)}

    case :httpc.request(:post, request, [timeout: timeout, connect_timeout: 3_000],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _, body}} -> decode(body)
      {:ok, {{_, 404, _}, _, _}} -> {:error, "Model unavailable. Run ollama pull #{model}."}
      {:ok, {{_, status, _}, _, _}} -> {:error, "Ollama returned HTTP #{status}."}
      {:error, :timeout} -> {:error, "Ollama timed out. Try a smaller model or offline mode."}
      {:error, _} -> {:error, "Cannot reach Ollama. Start Ollama and check OLLAMA_URL."}
    end
  rescue
    _ -> {:error, "Ollama request failed."}
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, %{"done" => true, "message" => %{"content" => text}} = response}
      when is_binary(text) and byte_size(text) <= 40_000 ->
        if response["done_reason"] == "length",
          do: {:error, "Ollama response was truncated."},
          else: {:ok, text}

      _ ->
        {:error, "Ollama returned an incomplete or invalid response."}
    end
  end
end
