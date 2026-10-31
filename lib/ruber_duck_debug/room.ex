defmodule RuberDuckDebug.Room do
  use GenServer, restart: :temporary
  alias RuberDuckDebug.{Challenges, RoundAI, Runner}
  @roles [:driver, :observer, :researcher]
  @idle_ms 3_600_000

  def start_link(code),
    do:
      GenServer.start_link(__MODULE__, code,
        name: {:via, Registry, {RuberDuckDebug.RoomRegistry, code}}
      )

  def init(code) do
    Process.send_after(self(), :expire, @idle_ms)

    {:ok,
     %{
       code: code,
       players: [],
       host: nil,
       round: 0,
       status: :lobby,
       turn: :researcher,
       challenge: nil,
       source: nil,
       code_text: "",
       result: nil,
       attempts: 0,
       hints: 0,
       duck:
         "Welcome! Invite two teammates. Driver edits, Observer reads evidence, Researcher proposes an experiment.",
       messages: [],
       events: [],
       debrief: nil,
       mode: "offline",
       last_active: now()
     }}
  end

  def handle_call({:join, id, name}, _from, state) do
    cond do
      Enum.any?(state.players, &(&1.id == id)) ->
        {:reply, :ok, state}

      length(state.players) >= 3 ->
        {:reply, {:error, "This room already has three players."}, state}

      not is_binary(name) or String.trim(name) == "" or byte_size(name) > 80 ->
        {:reply, {:error, "Enter a name (1–80 bytes)."}, state}

      true ->
        player = %{id: id, name: String.trim(name), role: Enum.at(@roles, length(state.players))}
        state = %{state | players: state.players ++ [player], host: state.host || id}
        {:reply, :ok, notify(state)}
    end
  end

  def handle_call({:view, id}, _from, state) do
    case Enum.find(state.players, &(&1.id == id)) do
      nil ->
        {:reply, {:error, "Join the room first."}, state}

      player ->
        public =
          Map.take(state, [
            :code,
            :round,
            :status,
            :turn,
            :attempts,
            :hints,
            :duck,
            :messages,
            :debrief,
            :mode,
            :source
          ])

        players = Enum.map(state.players, &Map.take(&1, [:name, :role]))

        view =
          Map.merge(public, %{
            player: Map.take(player, [:name, :role]),
            players: players,
            host?: state.host == id
          })

        view = private_view(view, state, player.role)
        {:reply, {:ok, view}, state}
    end
  end

  def handle_call({:action, id, action, params}, _from, state) do
    player = Enum.find(state.players, &(&1.id == id))

    if player do
      case act(action, params, player, state) do
        {:ok, next} -> {:reply, :ok, notify(next)}
        {:error, error} -> {:reply, {:error, error}, state}
      end
    else
      {:reply, {:error, "You are not a member of this room."}, state}
    end
  end

  def handle_info({:generated, round, result}, %{round: round, status: :generating} = state) do
    state =
      case result do
        {:ok, challenge} ->
          load(state, challenge, "Gemma · verified")

        {:error, reason} ->
          %{
            load(state, Challenges.get(round), "Offline fallback")
            | duck:
                "#{reason} Using a verified offline challenge. Researcher, propose your first experiment."
          }
      end

    {:noreply, notify(state)}
  end

  def handle_info({:checked, round, result}, %{round: round, status: :checking} = state) do
    case result do
      {:ok, result} ->
        state = %{
          state
          | result: result,
            status: :playing,
            turn: :observer,
            events:
              state.events ++
                [
                  %{
                    event: "check",
                    attempt: state.attempts,
                    passed: result["passed"],
                    results: result["results"]
                  }
                ],
            duck: "Check complete. Observer, describe the evidence before the next experiment."
        }

        {:noreply, notify(state)}

      {:error, error} ->
        state = %{state | status: :playing, turn: :driver, duck: error}
        {:noreply, notify(state)}
    end
  end

  def handle_info({:debrief, round, {:ok, text}}, %{round: round, status: :ended} = state) do
    {:noreply,
     notify(%{
       state
       | debrief: text,
         duck: "Gemma's review is ready. Read it together, then rotate roles."
     })}
  end

  def handle_info({:debrief, round, {:error, _}}, %{round: round, status: :ended} = state) do
    {:noreply,
     notify(%{
       state
       | duck: "The recorded review is ready. Gemma is unavailable; your results are preserved."
     })}
  end

  def handle_info(:expire, state) do
    if now() - state.last_active >= @idle_ms do
      {:stop, :normal, state}
    else
      Process.send_after(self(), :expire, @idle_ms)
      {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp act(action, _, _, %{events: events})
       when action in ["hypothesis", "submit", "hint", "chat"] and length(events) >= 100,
       do:
         {:error,
          "Round record limit reached. The host can end the round to review and start fresh."}

  defp act("start", params, %{id: id}, %{host: id, status: status} = state)
       when status in [:lobby, :ended] do
    if length(state.players) == 3 do
      round = state.round + 1

      players =
        if state.round > 0,
          do:
            Enum.map(
              state.players,
              &%{
                &1
                | role:
                    Enum.at(@roles, rem(Enum.find_index(@roles, fn r -> r == &1.role end) + 1, 3))
              }
            ),
          else: state.players

      mode = if params["mode"] == "ai", do: "ai", else: "offline"

      state = %{
        state
        | players: players,
          round: round,
          mode: mode,
          status: :generating,
          challenge: nil,
          code_text: "",
          result: nil,
          attempts: 0,
          hints: 0,
          events: [],
          messages: [],
          debrief: nil,
          duck: "Preparing a fresh round. Each role receives only its own material."
      }

      if mode == "ai" do
        job(:generated, round, fn -> RoundAI.generate(round) end)
        {:ok, state}
      else
        {:ok, load(state, Challenges.get(round), "Offline · verified")}
      end
    else
      {:error, "Three players must join before starting."}
    end
  end

  defp act(
         "hypothesis",
         %{"text" => text},
         %{role: :researcher} = player,
         %{status: :playing, turn: :researcher} = state
       ) do
    if valid_text?(text, 1500) do
      state = add_message(state, player, "Hypothesis: " <> String.trim(text))

      {:ok,
       %{
         state
         | turn: :driver,
           events: state.events ++ [%{event: "hypothesis", text: text}],
           duck: "Driver, apply the proposed experiment and request a check."
       }}
    else
      {:error, "Enter a hypothesis of 1–1500 bytes."}
    end
  end

  defp act(
         "submit",
         %{"code" => code},
         %{role: :driver},
         %{status: :playing, turn: :driver} = state
       ) do
    if valid_text?(code, 8000) do
      round = state.round
      challenge = state.challenge
      job(:checked, round, fn -> Runner.check(code, challenge) end)

      {:ok,
       %{
         state
         | code_text: code,
           status: :checking,
           attempts: state.attempts + 1,
           events: state.events ++ [%{event: "edit", code: code}],
           duck: "Checking the experiment…"
       }}
    else
      {:error, "Code must contain 1–8000 bytes."}
    end
  end

  defp act("review", _, %{role: :observer}, %{status: :playing, turn: :observer} = state) do
    if state.result["passed"] do
      {:ok, finish(state, "solved")}
    else
      {:ok,
       %{
         state
         | turn: :researcher,
           duck: "Researcher, use the Observer's evidence to refine your hypothesis."
       }}
    end
  end

  defp act("end", _, %{id: id}, %{host: id, status: :playing} = state),
    do: {:ok, finish(state, "unsolved")}

  defp act("hint", _, _, %{status: :playing} = state) do
    {:ok,
     %{
       state
       | hints: state.hints + 1,
         duck: state.challenge["hint"],
         events: state.events ++ [%{event: "hint", text: state.challenge["hint"]}]
     }}
  end

  defp act("chat", %{"text" => text}, player, state) do
    if valid_text?(text, 1500),
      do:
        {:ok,
         %{
           add_message(state, player, String.trim(text))
           | events:
               state.events ++ [%{event: "note", role: player.role, text: String.trim(text)}]
         }},
      else: {:error, "Message must contain 1–1500 bytes."}
  end

  defp act(_, _, _, _),
    do: {:error, "That action is not allowed for your role or the current turn."}

  defp finish(state, outcome) do
    challenge = state.challenge
    round = state.round

    if state.mode == "ai",
      do: job(:debrief, round, fn -> RoundAI.debrief(challenge, state.events, outcome) end)

    checks = Enum.filter(state.events, &(&1.event == "check"))
    failed = Enum.reject(checks, & &1.passed)

    right =
      if outcome == "solved",
        do: "Your final repair passed all supplied tests.",
        else:
          "You recorded #{Enum.count(state.events, &(&1.event == "hypothesis"))} proposed experiments and completed #{length(checks)} checks."

    wrong =
      if failed == [],
        do: "No completed checks failed.",
        else:
          "Failed checks: #{length(failed)}. " <>
            Enum.map_join(failed, " ", fn check ->
              "Attempt #{check.attempt}: #{Enum.count(check.results, & &1["passed"])}/#{length(check.results)} tests passed."
            end)

    debrief =
      "Outcome: #{outcome}.\n\nWhat went right: #{right}\n\nWhat went wrong: #{wrong} Unrecorded conversations cannot be assessed.\n\nHow the bug works: #{challenge["explanation"]}\n\nTakeaway: Test boundaries and small inputs before changing the implementation."

    %{
      state
      | status: :ended,
        debrief: debrief,
        duck:
          if(state.mode == "ai",
            do:
              "Round complete! Your recorded review is ready below. Gemma is preparing an additional review; starting the next round discards that pending review.",
            else:
              "Round complete! All challenge material is now revealed. Discuss the review together."
          )
    }
  end

  defp load(state, challenge, source) do
    %{
      state
      | challenge: challenge,
        code_text: challenge["code"],
        status: :playing,
        turn: :researcher,
        source: source,
        duck:
          "Researcher, ask the Observer about the symptoms, then propose a hypothesis. Driver, explain your code without sharing your screen."
    }
  end

  defp private_view(view, %{challenge: nil}, _),
    do: Map.merge(view, %{material: nil, editor: nil, result: nil, solution: nil, events: []})

  defp private_view(view, state, role) do
    c = state.challenge

    material =
      case role do
        :driver ->
          %{
            "title" => c["title"],
            "objective" => "Explain your function and apply the team's proposed repair."
          }

        :observer ->
          Map.take(c, ["title", "symptoms"])

        :researcher ->
          Map.take(c, ["title", "objective", "documentation"])
      end

    ended = state.status == :ended

    Map.merge(view, %{
      material: material,
      editor: if(role == :driver or ended, do: state.code_text),
      result: if(role == :observer or ended, do: state.result),
      solution: if(ended, do: c),
      events: if(ended, do: state.events, else: [])
    })
  end

  defp add_message(state, player, text),
    do: %{
      state
      | messages:
          Enum.take(state.messages ++ [%{name: player.name, role: player.role, text: text}], -100)
    }

  defp valid_text?(text, max),
    do: is_binary(text) and byte_size(text) <= max and String.trim(text) != ""

  defp job(kind, round, fun) do
    room = self()

    Task.Supervisor.start_child(RuberDuckDebug.AITasks, fn ->
      try do
        send(room, {kind, round, fun.()})
      rescue
        _ -> send(room, {kind, round, {:error, "The operation failed. Please retry."}})
      end
    end)
  end

  defp notify(state) do
    Phoenix.PubSub.broadcast(RuberDuckDebug.PubSub, "room:#{state.code}", :room_changed)
    %{state | last_active: now()}
  end

  defp now, do: System.monotonic_time(:millisecond)
end
