defmodule Syrup.Help do
  use Syrup.Definition

  def help(options // []) do
      Syrup.Definition.add! __MODULE__, options
  end

  def init(options) do
      {:ok, options}
  end

  defcall help, state: state do
      IO.puts "Syrup: Elixir/OTP build tool"
      IO.puts ""
      IO.puts "Usage: syrup [command]"
      {:reply, :ok, state}
  end

end