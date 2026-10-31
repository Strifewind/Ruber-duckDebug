defmodule RuberDuckDebugWeb.LobbyLive do
  use RuberDuckDebugWeb, :live_view
  alias RuberDuckDebug.Rooms

  def mount(params, _session, socket) do
    code = params |> Map.get("code", "") |> String.trim() |> String.upcase() |> String.slice(0, 6)
    {:ok, assign(socket, page_title: "Multiplayer lobby", room_code: code)}
  end

  def handle_event("create", %{"name" => name}, socket) do
    if String.trim(name) != "" and byte_size(name) <= 80 do
      case Rooms.create() do
        {:ok, code} -> join(socket, code, name)
        _ -> {:noreply, put_flash(socket, :error, "Could not create a room. Please retry.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Enter a name (1–80 bytes).")}
    end
  end

  def handle_event("join", %{"name" => name, "code" => code}, socket) do
    join(socket, String.upcase(String.trim(code)), name)
  end

  defp join(socket, code, name) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    case Rooms.call(code, {:join, id, name}) do
      :ok ->
        ticket =
          Phoenix.Token.sign(RuberDuckDebugWeb.Endpoint, "room-seat", %{room: code, id: id})

        {:noreply, push_navigate(socket, to: ~p"/rooms/#{code}?#{[seat: ticket]}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-4">
        <.link navigate={~p"/"} class="link">← Role previews</.link>
        <h1 class="text-3xl font-bold">Play with your team</h1>
        <p>
          Three players share one investigation. Create a room and share its code, or join your teammates below.
        </p>
        <p class="text-sm text-base-content/70">
          Live roles are assigned when joining and rotate after each round. A role chosen in the preview does not reserve a live seat.
        </p>
      </section>
      <section aria-label="Create or join a room" class="grid gap-6 pt-8 sm:grid-cols-2">
        <article class="space-y-4 rounded-box border border-base-300 bg-base-200 p-6">
          <h2 class="text-2xl font-semibold">Create a room</h2>
          <form id="create-room" phx-submit="create" class="flex flex-col gap-3">
            <label for="create-name" class="font-semibold">Your name</label>
            <input
              id="create-name"
              name="name"
              class="input w-full"
              required
              maxlength="40"
              placeholder="Your name"
              autocomplete="nickname"
            />
            <button class="btn btn-primary" type="submit">Create room →</button>
          </form>
        </article>
        <article class="space-y-4 rounded-box border border-base-300 bg-base-200 p-6">
          <h2 class="text-2xl font-semibold">Join a room</h2>
          <form id="join-room" phx-submit="join" class="flex flex-col gap-3">
            <label for="join-name" class="font-semibold">Your name</label>
            <input
              id="join-name"
              name="name"
              class="input w-full"
              required
              maxlength="40"
              placeholder="Your name"
              autocomplete="nickname"
            />
            <label for="room-code" class="font-semibold">Room code</label>
            <input
              id="room-code"
              name="code"
              value={@room_code}
              class="input w-full font-mono uppercase"
              required
              minlength="6"
              maxlength="6"
              placeholder="A1B2C3"
              autocomplete="off"
            />
            <button class="btn btn-primary" type="submit">Join investigation →</button>
          </form>
        </article>
      </section>
    </Layouts.app>
    """
  end
end
