defmodule RuberDuckDebugWeb.RoomLiveTest do
  use RuberDuckDebugWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias RuberDuckDebug.Rooms

  setup do
    {:ok, code} = Rooms.create()
    for id <- ~w(driver observer researcher), do: :ok = Rooms.call(code, {:join, id, id})
    :ok = Rooms.call(code, {:action, "driver", "start", %{}})
    %{code: code}
  end

  test "private materials stay out of the other roles' rendered HTML", %{conn: conn, code: code} do
    {:ok, driver, driver_html} = live(conn, seat_url(code, "driver"))
    {:ok, observer, observer_html} = live(build_conn(), seat_url(code, "observer"))
    {:ok, researcher, researcher_html} = live(build_conn(), seat_url(code, "researcher"))
    assert has_element?(driver, "#python-editor")
    refute has_element?(driver, "#documentation")
    refute has_element?(driver, "#symptoms")
    assert has_element?(observer, "#symptoms")
    refute has_element?(observer, "#python-editor")
    assert has_element?(researcher, "#documentation")
    refute has_element?(researcher, "#python-editor")

    for html <- [driver_html, observer_html, researcher_html] do
      refute html =~ "return sum(weights)"
      refute html =~ "range(len(weights)) visits"
    end
  end

  test "forged or cross-room seat links are rejected", %{conn: conn, code: code} do
    assert {:error, {:redirect, %{to: "/play"}}} = live(conn, "/rooms/#{code}?seat=forged")
    {:ok, other} = Rooms.create()

    ticket =
      Phoenix.Token.sign(RuberDuckDebugWeb.Endpoint, "room-seat", %{room: other, id: "driver"})

    assert {:error, {:redirect, %{to: "/play"}}} =
             live(build_conn(), "/rooms/#{code}?seat=#{ticket}")
  end

  test "messages synchronize and forged role events are rejected", %{conn: conn, code: code} do
    {:ok, driver, _} = live(conn, seat_url(code, "driver"))
    {:ok, researcher, _} = live(build_conn(), seat_url(code, "researcher"))
    researcher |> form("#chat-form", text: "Please describe the loop") |> render_submit()
    assert render(driver) =~ "Please describe the loop"
    render_click(driver, "hypothesis", %{"text" => "I am not the Researcher"})
    assert render(driver) =~ "not allowed"
  end

  defp seat_url(code, id) do
    ticket = Phoenix.Token.sign(RuberDuckDebugWeb.Endpoint, "room-seat", %{room: code, id: id})
    "/rooms/#{code}?seat=#{ticket}"
  end
end
