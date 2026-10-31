defmodule RuberDuckDebug.Assets do
  @moduledoc "Captures Tailwind output before writing, compatible with OneDrive folders on Windows."

  def build(args \\ []) do
    config = Tailwind.config_for!(:ruber_duck_debug)

    env =
      Enum.map(config[:env], fn {key, values} ->
        {key,
         if(is_list(values),
           do: Enum.join(values, if(match?({:win32, _}, :os.type()), do: ";", else: ":")),
           else: values
         )}
      end)

    cli_args = Enum.reject(config[:args], &String.starts_with?(&1, "--output="))

    case System.cmd(Tailwind.bin_path(), cli_args ++ args, cd: config[:cd], env: env) do
      {css, 0} ->
        output = Path.join(config[:cd], "priv/static/assets/css/app.css")
        File.mkdir_p!(Path.dirname(output))
        File.write!(output, css)
        :ok

      {_, status} ->
        {:error, status}
    end
  end
end
