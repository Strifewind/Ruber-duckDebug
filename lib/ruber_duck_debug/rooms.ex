defmodule RuberDuckDebug.Rooms do
  @moduledoc "Room discovery and server-authorized player operations."
  alias RuberDuckDebug.Room

  def create do
    code = Base.encode16(:crypto.strong_rand_bytes(3))

    case DynamicSupervisor.start_child(RuberDuckDebug.RoomSupervisor, {Room, code}) do
      {:ok, _} -> {:ok, code}
      error -> error
    end
  end

  def call(code, message) when is_binary(code) do
    case Registry.lookup(RuberDuckDebug.RoomRegistry, String.upcase(code)) do
      [{pid, _}] -> GenServer.call(pid, message)
      [] -> {:error, "Room not found. Check the code or create a new room."}
    end
  catch
    :exit, _ -> {:error, "Room unavailable. Please rejoin."}
  end

  def subscribe(code), do: Phoenix.PubSub.subscribe(RuberDuckDebug.PubSub, "room:#{code}")
end
