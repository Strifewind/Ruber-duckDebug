defmodule RuberDuckDebugWeb.HomeLiveTest do
  use RuberDuckDebugWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "home page introduces the cooperative roles", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#welcome-heading", "Debug together")
    assert has_element?(view, "#welcome-heading span.text-base-content", "with the duck.")
    assert has_element?(view, "button[phx-value-role='Driver']", "Driver")
    assert has_element?(view, "button[phx-value-role='Observer']", "Observer")
    assert has_element?(view, "button[phx-value-role='Researcher']", "Researcher")

    view |> element("button[phx-value-role='Driver']") |> render_click()
    view |> element("button", "Change role") |> render_click()

    assert has_element?(view, "h2", "Choose your role")
  end

  test "duck cycles through facilitation questions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    view |> element("button[phx-value-role='Driver']") |> render_click()

    assert has_element?(view, "#duck-prompt", "What evidence supports that hypothesis?")

    view |> element("#next-prompt") |> render_click()

    assert has_element?(
             view,
             "#duck-prompt",
             "What would you expect to observe if your hypothesis is correct?"
           )

    for _ <- 1..3, do: view |> element("#next-prompt") |> render_click()

    assert has_element?(view, "#duck-prompt", "What evidence supports that hypothesis?")
  end

  test "new visits start with the initial public prompt", %{conn: conn} do
    {:ok, first_view, _html} = live(conn, ~p"/")
    first_view |> element("button[phx-value-role='Driver']") |> render_click()
    first_view |> element("#next-prompt") |> render_click()

    {:ok, second_view, _html} = live(build_conn(), ~p"/")
    second_view |> element("button[phx-value-role='Driver']") |> render_click()

    assert has_element?(second_view, "#duck-prompt", "What evidence supports that hypothesis?")
  end
end
