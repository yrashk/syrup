defmodule Syrup.Application do
  use Syrup.Definition

  def application(app) do
      Syrup.Definition.add! __MODULE__, app
  end

  def init(app) do
      state = Keyword.merge app, defaults
      {:ok, state}
  end

  defp defaults do
      {:ok, cwd} = :file.get_cwd
      [build_path: "builds", base_dir: cwd,
       compiler_options: [ignore_module_conflict: true]]
  end

  alias List.Chars, as: LC

  defcall build, state: app do
      Code.compiler_options app[:compiler_options]

      app_name_atom = list_to_atom(LC.to_char_list app[:name])
      app_name = LC.to_char_list app_name_atom

      base_dir = app[:base_dir]
      build_path = app[:build_path]
      compile_path = :filename.join([base_dir, build_path, "#{app_name}-#{app[:version]}","ebin"])
      :filelib.ensure_dir iolist_to_binary([compile_path, "/"])
      to_compile = extract_files(["lib"])
      if Enum.find(to_compile, stale?(&1, compile_path <> "/__MAIN__")) do
          Enum.each(["lib"], fn(path) ->
              files = File.wildcard(File.join([path, "**/*.ex"]))
              compile_files(files, compile_path)
              end)
      end
      app_file(app)
      {:reply, :ok, app}
  end

  defp app_file(app) do
      app_name_atom = list_to_atom(LC.to_char_list app[:name])
      app_name = LC.to_char_list app_name_atom

      build_path = app[:build_path]
      compile_path = "#{build_path}/#{app_name}-#{app[:version]}/ebin"

      modules = 
      lc file in File.wildcard("#{compile_path}/**/*.beam") do
          s = Regex.replace_all(%r/\//, Regex.replace(%r/#{compile_path}\/__MAIN__\/(.+)\.beam/, file, "\\1"), ".")
          Module.concat [s]
      end

       best_guess_app = [vsn: (LC.to_char_list (app[:version]||app[:vsn])), modules: modules]
       app = Keyword.from_enum(
               lc {key, mapping} in [description: :description,
                        id: :id, modules: :modules,
                        max_p: :maxP, max_t: :max_T,
                        registered: :registered, 
                        included_applications: :included_applications,
                        applications: :applications,
                        env: :env, mod: :mod, start_phases: :start_phases] when app[mapping] != nil, do:
                  {key, app[mapping]})
      
       app = {:application, app_name_atom, Keyword.merge best_guess_app, app}

       # write down the .app file
       {:ok, f} = :file.open(File.join([compile_path, "#{app_name}.app"]),[:write])
       :io.fwrite(f, "~p.", [app])
       :file.close(f)
   end

  

  defp extract_files(paths) do
    List.concat(lc path in paths, do: File.wildcard(File.join([path, "**/*.ex"])))
  end

  defp compile_files(files, to) do
    Elixir.ParallelCompiler.files_to_path(files, to, fn(x) ->
      IO.puts Enum.join(["Compiling ", x])
      x 
    end)
  end

  defp stale?(file, to) do
    {:ok, file_info} = File.read_info(file)
    case File.read_info(to) do
    {:ok, to_info} ->
      file_info.mtime > to_info.mtime
    {:error, _} ->
      true
    end
  end


end
