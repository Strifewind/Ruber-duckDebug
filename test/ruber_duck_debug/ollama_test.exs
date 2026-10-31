defmodule RuberDuckDebug.OllamaTest do
  use ExUnit.Case, async: false
  alias RuberDuckDebug.{Challenges, Ollama, RoundAI, Rooms}

  setup do
    old_url = System.get_env("OLLAMA_URL")
    old_model = System.get_env("OLLAMA_MODEL")
    System.put_env("OLLAMA_MODEL", "gemma3:4b")

    on_exit(fn ->
      restore("OLLAMA_URL", old_url)
      restore("OLLAMA_MODEL", old_model)
    end)

    :ok
  end

  test "sends stateless non-streaming messages to the configured local model" do
    stub(200, response("Quack!"))
    assert {:ok, "Quack!"} = Ollama.chat([%{role: "user", content: "Hello"}])
    assert_receive {:ollama_request, request}
    assert request["model"] == "gemma3:4b"
    assert request["stream"] == false
    assert request["messages"] == [%{"role" => "user", "content" => "Hello"}]
  end

  test "model missing produces an actionable error" do
    stub(404, "{}")
    assert {:error, message} = Ollama.chat([])
    assert message =~ "ollama pull gemma3:4b"
  end

  test "incomplete and truncated responses are rejected" do
    stub(200, Jason.encode!(%{done: true, done_reason: "length", message: %{content: "partial"}}))
    assert {:error, message} = Ollama.chat([])
    assert message =~ "truncated"
  end

  test "malformed response is rejected" do
    stub(200, "not JSON")
    assert {:error, _} = Ollama.chat([])
  end

  test "fresh round context requests structured output and verifies generated code" do
    challenge = Challenges.get(1)
    stub(200, response(Jason.encode!(challenge)))
    assert {:ok, ^challenge} = RoundAI.generate(9)
    assert_receive {:ollama_request, request}

    assert [
             %{"role" => "system", "content" => system},
             %{"role" => "user"},
             %{"role" => "assistant", "content" => example},
             %{"role" => "user", "content" => prompt}
           ] =
             request["messages"]

    assert system =~ "ROUND-END REVIEW"
    assert system =~ "Driver:"
    assert prompt =~ "Round ID: 9"
    assert Jason.decode!(example) == Challenges.get(1)
    assert request["format"]["type"] == "object"
  end

  test "an unverified AI package cannot become a playable challenge" do
    bad = Map.put(Challenges.get(1), "solution", "def parcel_total(weights):\n    return -1")
    stub(200, response(Jason.encode!(bad)))
    assert {:error, _} = RoundAI.generate()
  end

  test "model failure falls back without blocking the room" do
    stub(503, "{}")
    {:ok, code} = Rooms.create()
    for id <- ~w(driver observer researcher), do: :ok = Rooms.call(code, {:join, id, id})
    assert :ok = Rooms.call(code, {:action, "driver", "start", %{"mode" => "ai"}})

    await(fn ->
      {:ok, room} = Rooms.call(code, {:view, "driver"})
      room.status == :playing and room.source == "Offline fallback"
    end)
  end

  test "debrief contains recorded evidence and no retained conversation" do
    stub(200, response("Outcome: solved. Good boundary testing."))

    assert {:ok, _} =
             RoundAI.debrief(Challenges.get(1), [%{event: "check", passed: true}], "solved")

    assert_receive {:ollama_request, request}
    assert length(request["messages"]) == 2
    prompt = List.last(request["messages"])["content"]
    assert prompt =~ "ENDED"
    assert prompt =~ "solved"
    assert prompt =~ "check"
  end

  test "slow model requests return a timeout instead of blocking indefinitely" do
    stub(200, response("Late reply"), delay: 100)
    assert {:error, message} = Ollama.chat([], timeout: 10)
    assert message =~ "timed out"
  end

  test "HTTP failure returns a useful error" do
    stub(503, "{}")
    assert {:error, "Ollama returned HTTP 503."} = Ollama.chat([])
  end

  defp stub(status, body, extra \\ []) do
    pid =
      start_supervised!(
        {Bandit,
         [
           plug:
             {RuberDuckDebug.OllamaStub, [owner: self(), status: status, body: body] ++ extra},
           port: 0,
           ip: {127, 0, 0, 1}
         ]}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    System.put_env("OLLAMA_URL", "http://127.0.0.1:#{port}")
  end

  defp response(text),
    do:
      Jason.encode!(%{
        done: true,
        done_reason: "stop",
        message: %{role: "assistant", content: text}
      })

  defp restore(key, nil), do: System.delete_env(key)
  defp restore(key, value), do: System.put_env(key, value)
  defp await(fun, remaining \\ 100)
  defp await(fun, 0), do: assert(fun.())

  defp await(fun, remaining) do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(20)
          await(fun, remaining - 1)
        )
  end
end
