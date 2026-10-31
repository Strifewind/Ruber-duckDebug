defmodule RuberDuckDebug.Rooms do
  @moduledoc "Room discovery and server-authorized player operations."
  alias RuberDuckDebug.Room
  @code_format ~r/\A[A-Z2-7]{20}\z/

  def create do
    code = Base.encode32(:crypto.strong_rand_bytes(12), padding: false)

    case DynamicSupervisor.start_child(RuberDuckDebug.RoomSupervisor, {Room, code}) do
      {:ok, _} -> {:ok, code}
      error -> error
    end
  end

  def call(code, message) when is_binary(code) do
    code = String.upcase(code)

    if Regex.match?(@code_format, code) do
      case Registry.lookup(RuberDuckDebug.RoomRegistry, code) do
        [{pid, _}] -> GenServer.call(pid, message)
        [] -> {:error, "Room not found. Check the code or create a new room."}
      end
    else
      {:error, "Room not found. Check the code or create a new room."}
    end
  catch
    :exit, _ -> {:error, "Room unavailable. Please rejoin."}
  end

  def subscribe(code), do: Phoenix.PubSub.subscribe(RuberDuckDebug.PubSub, "room:#{code}")
end
