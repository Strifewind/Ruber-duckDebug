defmodule RuberDuckDebug.RoomTest do
  use ExUnit.Case, async: true
  alias RuberDuckDebug.{Rooms, Challenges}

  setup do
    {:ok, code} = Rooms.create()

    for {id, name} <- [{"driver", "Alice"}, {"observer", "Bob"}, {"researcher", "Carol"}] do
      assert :ok = Rooms.call(code, {:join, id, name})
    end

    [{pid, _}] = Registry.lookup(RuberDuckDebug.RoomRegistry, code)

    on_exit(fn ->
      if Process.alive?(pid),
        do: DynamicSupervisor.terminate_child(RuberDuckDebug.RoomSupervisor, pid)
    end)

    %{code: code}
  end

  test "membership, capacity, host and turn authorization are enforced", %{code: code} do
    assert {:error, _} = Rooms.call(code, {:join, "fourth", "Mallory"})
    assert {:error, _} = Rooms.call(code, {:view, "stranger"})
    assert {:error, _} = action(code, "observer", "start")
    assert :ok = action(code, "driver", "start")
    assert {:error, _} = action(code, "observer", "hypothesis", %{"text" => "guess"})

    assert {:error, _} =
             action(code, "driver", "submit", %{"code" => Challenges.get(1)["solution"]})

    assert {:error, _} = action(code, "observer", "end")
  end

  test "role views never expose another role's private package before debrief", %{code: code} do
    assert :ok = action(code, "driver", "start")
    driver = view(code, "driver")
    observer = view(code, "observer")
    researcher = view(code, "researcher")
    assert driver.editor == Challenges.get(1)["code"]
    assert observer.editor == nil
    assert researcher.editor == nil
    assert observer.material["symptoms"]
    refute driver.material["symptoms"]
    assert researcher.material["documentation"]
    refute observer.material["documentation"]

    for data <- [driver, observer, researcher] do
      assert data.solution == nil
      assert data.events == []
      refute Map.has_key?(data, :challenge)
    end
  end

  test "complete failed experiment, successful repair, debrief and fresh round", %{code: code} do
    assert :ok = action(code, "driver", "start")
    assert :ok = action(code, "researcher", "hypothesis", %{"text" => "Check all indices"})
    assert :ok = action(code, "driver", "submit", %{"code" => Challenges.get(1)["code"]})
    await(fn -> view(code, "observer").turn == :observer end)
    assert view(code, "observer").result["passed"] == false
    assert view(code, "driver").result == nil
    assert view(code, "researcher").result == nil
    assert :ok = action(code, "observer", "review")
    assert :ok = action(code, "researcher", "hypothesis", %{"text" => "Visit the last item too"})
    assert :ok = action(code, "driver", "submit", %{"code" => Challenges.get(1)["solution"]})
    await(fn -> view(code, "observer").turn == :observer end)
    assert :ok = action(code, "observer", "review")
    ended = view(code, "driver")
    assert ended.status == :ended
    assert ended.solution["solution"]
    assert ended.debrief =~ "solved"
    assert ended.debrief =~ "Failed checks: 1"
    assert ended.attempts == 2
    assert :ok = action(code, "driver", "start")
    fresh = view(code, "driver")
    assert fresh.round == 2
    assert fresh.player.role == :observer
    assert fresh.attempts == 0
    assert fresh.result == nil
    assert fresh.solution == nil
    assert fresh.events == []
    assert fresh.messages == []
    assert fresh.debrief == nil
    assert fresh.editor == nil
  end

  test "broadcasts contain no challenge data", %{code: code} do
    Rooms.subscribe(code)
    assert :ok = action(code, "driver", "start")
    assert_receive :room_changed
    refute_receive {:challenge, _}, 20
  end

  defp action(code, id, action, params \\ %{}),
    do: Rooms.call(code, {:action, id, action, params})

  defp view(code, id) do
    {:ok, room} = Rooms.call(code, {:view, id})
    room
  end

  defp await(fun, remaining \\ 150)
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
