defmodule Syrup.TestSuite do
  use Syrup.Entity

  def test_suite(suite // []) do
    Syrup.Entity.add! __MODULE__, suite
  end

  def init(suite) do
    state = Keyword.merge suite, defaults
    {:ok, state}
  end

  def defaults do
    [type: :eunit, test_paths: ["test"], test_pattern: "*_test.exs"]
  end

  defcall test, state: app do
    :ok = ExUnit.start []
    Enum.each(app[:test_paths], fn(path) ->
      Enum.each(File.wildcard(File.join([path, "**", app[:test_pattern]])), fn(file) ->
       Code.require_file file
      end)
     end)
     ExUnit.run
     {:reply, :ok, app}
  end


end
