defmodule RuberDuckDebug.OllamaStub do
  @moduledoc false
  def init(opts), do: opts

  def call(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    send(opts[:owner], {:ollama_request, Jason.decode!(body)})
    if opts[:delay], do: Process.sleep(opts[:delay])
    Plug.Conn.send_resp(conn, opts[:status] || 200, opts[:body])
  end
end
