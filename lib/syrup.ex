require GenX.GenServer

defmodule Syrup.Definition do
     
     def add!(module, app), do: {:ok, _pid} = :supervisor.start_child(Syrup.Definitions, [module, [app]])
     def start_link(module, args), do: :erlang.apply(module, :start_link, args)

     def run(definition, task) do
         module = :gen_server.call(definition, :get_module)
         task_atom = list_to_atom(List.Chars.to_char_list task)
         if :erlang.function_exported(module, task_atom, 1) do
             :gen_server.call(definition, task_atom)
         end
     end

     defmacro __using__(_) do
         quote do
           use GenServer.Behavior
           import GenX.GenServer

           def start_link(thing), do: :gen_server.start_link(__MODULE__, thing, [])
           def init(thing), do: {:ok, thing}

           defcall get_module(), state: state, do: {:reply, __MODULE__, state}

           defoverridable [init: 1]
         end
     end
end

defmodule Syrup.Syrupfile do
  use GenServer.Behavior
  import GenX.GenServer
  alias :gen_server, as: GenServer

  defrecord State, file: "syrup.exs", task: "default", starter: nil

  def start_link(task, starter), do: GenServer.start_link({:local, __MODULE__}, __MODULE__, {task, starter}, [])
   
    
  def init({task, starter}) do
    GenServer.cast(Process.self, :init)
    {:ok, State.new(task: task, starter: starter)}
  end

  defcast run(task), state: State[starter: starter]=state do
    children = :supervisor.which_children(Syrup.Definitions)
    lc {_, pid, _, _} in children, do: Syrup.Definition.run(pid, task)
    starter <- :stop
    {:noreply, state}
  end
 

  defcast init, state: State[task: task] = state, export: false do
    if :filelib.is_file("syrup.exs"), do: Code.require_file("syrup")
    run(Process.self, task)
    {:noreply, state}
  end
end

defmodule Syrup.Sup do
    alias GenX.Supervisor, as: S
    
    def start_link do
      task =
      case :application.get_env(Syrup, :args) do
        {:ok, [h]} -> h
        {:ok, []} -> "default"
      end
      {:ok, starter} = :application.get_env(Syrup, :starter)
      tree = S.OneForOne.new(id: __MODULE__, registered: __MODULE__,
                             children: [S.Worker.new(id: Syrup.Syrupfile, 
                                                     start_func: {Syrup.Syrupfile, :start_link, [task, starter]}),
                                        S.SimpleOneForOne.new(id: Syrup.Definitions, registered: Syrup.Definitions, shutdown: :infinity,
                                                     children: [S.Worker.new(id: Syrup.Definition)])])
      S.start_link tree
    end
end
defmodule Syrup.App do
     @behavior :application
     def start(_type, _args), do: Syrup.Sup.start_link
     def stop(_), do: :ok
end

defmodule Syrup do

  defdelegate [task: 1], to: Syrup.Task
  defdelegate [application: 1], to: Syrup.Application

  def start(args // System.argv) do
     :application.load(Syrup)
     :application.set_env(Syrup, :args, args)
     :application.set_env(Syrup, :starter, Process.self)
     :ok = :application.start(Syrup)
     receive do
      :stop -> 
         :application.stop(Syrup)
         IO.puts ""
         :ok
     end
  end

end
