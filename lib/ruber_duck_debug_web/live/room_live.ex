defmodule RuberDuckDebugWeb.RoomLive do
  use RuberDuckDebugWeb, :live_view
  alias RuberDuckDebug.Rooms

  def mount(%{"code" => code, "seat" => ticket}, _session, socket) do
    with {:ok, %{room: ^code, id: id}} <-
           Phoenix.Token.verify(RuberDuckDebugWeb.Endpoint, "room-seat", ticket, max_age: 43_200),
         {:ok, room} <- Rooms.call(code, {:view, id}) do
      if connected?(socket), do: Rooms.subscribe(code)

      {:ok,
       assign(socket,
         page_title: "Room #{code}",
         room_code: code,
         player_id: id,
         room: room,
         is_talking: false,
         draft: room.editor || ""
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "This seat link is invalid or expired. Join using the room code.")
         |> redirect(to: ~p"/play")}
    end
  end

  def mount(_, _, socket),
    do:
      {:ok,
       socket
       |> put_flash(:info, "Enter your name and room code to join.")
       |> redirect(to: ~p"/play")}

  def handle_event("draft", %{"code" => code}, socket),
    do: {:noreply, assign(socket, draft: code)}

  def handle_event(action, params, socket)
      when action in ~w(start hypothesis submit review hint chat end) do
    case Rooms.call(socket.assigns.room_code, {:action, socket.assigns.player_id, action, params}) do
      :ok ->
        socket =
          if action in ["chat", "hypothesis"],
            do:
              push_event(socket, "clear-form", %{
                id: if(action == "chat", do: "chat-form", else: "hypothesis-form")
              }),
            else: socket

        {:noreply, refresh(socket)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}
  def handle_info(:room_changed, socket), do: {:noreply, refresh(socket)}
  def handle_info(:stop_talking, socket), do: {:noreply, assign(socket, is_talking: false)}

  defp refresh(socket) do
    case Rooms.call(socket.assigns.room_code, {:view, socket.assigns.player_id}) do
      {:ok, room} ->
        reset? =
          room.round != socket.assigns.room.round or
            room.player.role != socket.assigns.room.player.role or
            (socket.assigns.room.status == :generating and room.status == :playing)

        socket = if reset?, do: assign(socket, draft: room.editor || ""), else: socket
        talking? = room.duck != socket.assigns.room.duck
        if talking?, do: Process.send_after(self(), :stop_talking, 3000)
        assign(socket, room: room, is_talking: talking? or socket.assigns.is_talking)

      {:error, error} ->
        socket |> put_flash(:error, error) |> push_navigate(to: ~p"/play")
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <RuberDuckDebugWeb.HomeLive.quackula_style />
      <section class="duck-room-header">
        <div>
          <p class="duck-eyebrow">Investigation room</p><h1 id="room-code-display">{@room.code}</h1><p>
            Share this code · Keep your seat URL private
          </p>
        </div>

        <div class="duck-room-meta">
          <span class="duck-badge">Round {@room.round}</span><span class="duck-badge">{status_label(
            @room.status
          )}</span><span class="duck-badge">{@room.attempts} checks</span>
        </div>
      </section>

      <section class="duck-role-grid" aria-label="Team">
        <article
          :for={player <- @room.players}
          data-role={player.role}
          class={["duck-player", player.role == @room.player.role && "duck-player-self"]}
        >
          <p class="duck-eyebrow">{player.role}</p><strong>{player.name}</strong><span :if={
            player.role == @room.player.role
          }>You</span>
        </article>

        <article :for={_ <- empty_seats(@room.players)} class="duck-player duck-player-empty">
          <p>Waiting for a teammate…</p>
        </article>
      </section>

      <section class="duck-host" aria-label="Duck host">
        <RuberDuckDebugWeb.HomeLive.quackula_svg size="80" is_talking={@is_talking} /><div>
          <p class="duck-eyebrow">Your host, Quackula</p><p id="duck-message" aria-live="polite">
            {@room.duck}
          </p>
        </div>
      </section>

      <section :if={@room.status in [:lobby, :ended]} class="duck-panel">
        <h2>
          {if @room.status == :ended, do: "Ready to rotate roles?", else: "Gather your debugging team"}
        </h2>

        <p>Three players are required. You can join from separate tabs to preview each role.</p>

        <form :if={@room.host?} id="start-round" phx-submit="start" class="duck-start-form">
          <label for="mode">Challenge source</label>
          <select id="mode" name="mode"><option value="offline">
            Offline · curated Python challenge
          </option><option value="ai">Gemma · generate and verify a new challenge</option></select>
          <button class="btn btn-primary" disabled={length(@room.players) != 3}>Start {if @room.round >
                                                                                            0,
                                                                                          do: "next",
                                                                                          else:
                                                                                            "first"} round →</button>
        </form>

        <p :if={!@room.host?}>Your room creator will start the round.</p>
      </section>

      <section :if={@room.status in [:generating, :checking]} class="duck-loading" role="status">
        <span class="loading loading-spinner"></span>{if @room.status == :generating,
          do: "Preparing your challenge. Gemma can take up to 90 seconds…",
          else: "Running the team's experiment…"}
      </section>

      <section :if={@room.material} class="duck-game-grid">
        <article class="duck-panel duck-workspace">
          <div class="duck-panel-heading">
            <div>
              <p class="duck-eyebrow">Private workspace · {@room.player.role}</p><h2>
                {@room.material["title"]}
              </h2>
            </div><span class="duck-badge">Python</span>
          </div>

          <p class="duck-source">{@room.source}</p>

          <p :if={@room.material["objective"]} class="duck-objective">
            {@room.material["objective"]}
          </p>

          <section :if={@room.material["documentation"]} id="documentation" class="duck-document">
            <h3>Language reference</h3><p>{@room.material["documentation"]}</p>
          </section>

          <section :if={@room.material["symptoms"]} id="symptoms" class="duck-document">
            <h3>Observed behavior</h3><p>{@room.material["symptoms"]}</p>
          </section>

          <form
            :if={@room.player.role == :driver}
            id="code-form"
            phx-submit="submit"
            phx-change="draft"
            class="duck-form"
          >
            <label for="python-editor">Python editor</label> <textarea
              id="python-editor"
              phx-hook="PythonEditor"
              name="code"
              rows="15"
              spellcheck="false"
              autocapitalize="off"
              autocomplete="off"
              maxlength="8000"
              readonly={@room.status != :playing or @room.turn != :driver}
            >{@draft}</textarea>
            <p class="duck-footnote">
              Supported: one function, numbers, booleans, lists, if/for, comparisons, arithmetic, indexing; len, sum, min, max, abs, sorted, range. No imports or arbitrary execution.
            </p>

            <button
              class="btn btn-primary"
              disabled={@room.status != :playing or @room.turn != :driver}
            >Run experiment →</button>
          </form>

          <form
            :if={@room.player.role == :researcher and @room.status == :playing}
            id="hypothesis-form"
            phx-submit="hypothesis"
            class="duck-form"
          >
            <label for="hypothesis">Your hypothesis and proposed experiment</label> <textarea
              id="hypothesis"
              name="text"
              rows="4"
              required
              maxlength="1500"
              placeholder="I think… We can test this by…"
              disabled={@room.turn != :researcher}
            ></textarea>
            <button class="btn btn-primary" disabled={@room.turn != :researcher}>Pass experiment to Driver →</button>
          </form>

          <section :if={@room.result} id="test-results" class="duck-document">
            <h3>
              Experiment results · {Enum.count(@room.result["results"], & &1["passed"])}/{length(
                @room.result["results"]
              )} passed
            </h3>

            <div
              :for={{result, index} <- Enum.with_index(@room.result["results"], 1)}
              class={["duck-test", result["passed"] && "duck-test-pass"]}
            >
              <strong>{if result["passed"], do: "✓", else: "×"} Check {index}</strong>
              <p>Input: <code>{Jason.encode!(result["args"])}</code></p><p>
                Expected: <code>{Jason.encode!(result["expected"])}</code>
              </p><p>Observed: <code>{result["error"] || Jason.encode!(result["actual"])}</code></p>
            </div>
          </section>

          <button
            :if={@room.player.role == :observer and @room.status == :playing}
            id="review-results"
            phx-click="review"
            class="btn btn-primary"
            disabled={@room.turn != :observer}
          >I've shared the evidence →</button>
        </article>

        <aside class="duck-sidebar">
          <article class="duck-panel">
            <p class="duck-eyebrow">The investigation loop</p><ol class="duck-turns">
              <li
                :for={role <- [:researcher, :driver, :observer]}
                class={@room.turn == role && "duck-turn-active"}
              >
                <strong>{role}</strong><span>{role_instruction(role)}</span>
              </li>
            </ol>

            <div :if={@room.status == :playing} class="duck-controls">
              <button phx-click="hint" class="btn btn-outline btn-sm">Ask Duck for a hint</button><button
                :if={@room.host?}
                phx-click="end"
                class="btn btn-ghost btn-sm"
                data-confirm="End this round and reveal the solution?"
              >End & review</button>
            </div>
          </article>

          <article class="duck-panel">
            <h2>Team notebook</h2><p class="duck-footnote">
              Share observations here or use your own voice call.
            </p>

            <div id="team-messages" class="duck-messages" role="log" aria-label="Team messages">
              <p :if={@room.messages == []}>No notes yet. Start with what you can observe.</p><div
                :for={{message, index} <- Enum.with_index(@room.messages)}
                id={"message-#{index}"}
                class="duck-message"
              >
                <strong>{message.name} <small>{message.role}</small></strong><p>{message.text}</p>
              </div>
            </div>

            <form id="chat-form" phx-submit="chat" class="duck-form">
              <label for="chat-message">Message your team</label><textarea
                id="chat-message"
                name="text"
                rows="2"
                required
                maxlength="1500"
              ></textarea><button class="btn btn-outline btn-sm">Send note</button>
            </form>
          </article>
        </aside>
      </section>

      <section :if={@room.status == :ended} id="round-review" class="duck-panel">
        <p class="duck-eyebrow">Shared debrief</p><h2>What did we learn?</h2><p class="duck-review">
          {@room.debrief}
        </p>

        <details>
          <summary>Reveal the reference solution and round record</summary><h3>Reference solution</h3><pre class="duck-reference">{@room.solution["solution"]}</pre><h3>
            Recorded actions and evidence
          </h3><pre class="duck-reference">{Jason.encode!(@room.events, pretty: true)}</pre>
        </details>
      </section>
    </Layouts.app>
    """
  end

  defp empty_seats(players), do: List.duplicate(nil, 3 - length(players))
  defp status_label(:lobby), do: "Lobby"
  defp status_label(:generating), do: "Preparing"
  defp status_label(:playing), do: "In progress"
  defp status_label(:checking), do: "Checking"
  defp status_label(:ended), do: "Round complete"
  defp role_instruction(:researcher), do: "Propose an experiment"
  defp role_instruction(:driver), do: "Edit and request checks"
  defp role_instruction(:observer), do: "Explain the evidence"
end
