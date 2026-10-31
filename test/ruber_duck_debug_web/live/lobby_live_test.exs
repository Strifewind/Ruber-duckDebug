defmodule RuberDuckDebugWeb.LobbyLiveTest do
  use RuberDuckDebugWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "main preview remains reachable and links to the additional lobby", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/")
    assert has_element?(view, "a[href='/play']", "Play with your team")
    assert has_element?(view, "button[phx-value-role='Driver']")
    view |> element("button[phx-value-role='Driver']") |> render_click()
    assert has_element?(view, ".beak-bottom")
    view |> element("#next-prompt") |> render_click()
    assert has_element?(view, ".is-talking .beak-bottom")
  end

  test "lobby creates a room and signs a seat link", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    view |> form("#create-room", name: "Alice") |> render_submit()
    {path, _} = assert_redirect(view)
    assert path =~ ~r"/rooms/[A-F0-9]{6}\?seat="
    {:ok, room, _} = live(build_conn(), path)
    assert has_element?(room, "#room-code-display")
    assert render(room) =~ "Alice"
    assert has_element?(room, ".beak-bottom")
  end

  test "unknown room is reported without leaving the lobby", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    view |> form("#join-room", name: "Bob", code: "NOPE00") |> render_submit()
    assert render(view) =~ "Room not found"
  end

  test "three tabs can join independently and the host can start", %{conn: conn} do
    {:ok, host, _} = live(conn, ~p"/play")
    host |> form("#create-room", name: "Alice") |> render_submit()
    {path, _} = assert_redirect(host)
    {:ok, room, _} = live(build_conn(), path)
    [_, code] = Regex.run(~r"/rooms/([A-F0-9]{6})\?", path)

    for name <- ["Bob", "Carol"] do
      {:ok, lobby, _} = live(build_conn(), ~p"/play")
      lobby |> form("#join-room", name: name, code: code) |> render_submit()
      assert_redirect(lobby)
    end

    room |> form("#start-round", mode: "offline") |> render_submit()
    assert has_element?(room, "#python-editor")
    assert render(room) =~ "The missing parcel"
  end
end
