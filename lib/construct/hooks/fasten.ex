defmodule Construct.Hooks.Fasten do
  defmacro __using__(_opts \\ []) do
    quote do
      structure_compile_hook :post do
        Module.eval_quoted(__MODULE__, Construct.Hooks.Fasten.__compile__(__MODULE__, Enum.reverse(@fields)))

        defoverridable make: 2
      end
    end
  end

  def __compile__(module, fields) do
    cast_defs =
      Enum.map(fields, fn({name, type, opts}) ->
        {default_before_clause, default_after_clause} =
          case Keyword.get(opts, :default) do
            :__construct_no_default_value__ ->
              clause_after =
                quote do
                  def unquote(:"cast_#{name}")(_, _) do
                    {:error, %{unquote(name) => :missing}}
                  end
                end

              {[], clause_after}

            nil ->
              clause_after =
                quote do
                  def unquote(:"cast_#{name}")(_, _) do
                    {:error, %{unquote(name) => :missing}}
                  end
                end

              {[], clause_after}

            term ->
              term = Macro.escape(term)

              clause_before =
                quote do
                  def unquote(:"cast_#{name}")(%{unquote(to_string(name)) => term}, _opts) when term == unquote(term) do
                    {:ok, unquote(term)}
                  end

                  def unquote(:"cast_#{name}")(%{unquote(name) => term}, _opts) when term == unquote(term) do
                    {:ok, unquote(term)}
                  end
                end

              clause_after =
                quote do
                  def unquote(:"cast_#{name}")(_, _) do
                    {:ok, unquote(term)}
                  end
                end

              {clause_before, clause_after}
          end

        cast_clause =
          quote do
            def unquote(:"cast_#{name}")(%{unquote(to_string(name)) => term}, opts) do
              Construct.Type.cast(unquote(type), term, opts)
            end

            def unquote(:"cast_#{name}")(%{unquote(name) => term}, opts) do
              Construct.Type.cast(unquote(type), term, opts)
            end
          end

        default_before_clause |> merge_blocks(cast_clause) |> merge_blocks(default_after_clause)
      end)

    cast_defs =
      Enum.reduce(cast_defs, {:__block__, [], []}, fn(ast, acc) ->
        merge_blocks(acc, ast)
      end)

    with_body =
      Enum.map(fields, fn({name, _type, _opts}) ->
        {name, Macro.var(name, nil)}
      end)

    with_body =
      quote do
        {:ok, struct(unquote(module), unquote(with_body))}
      end

    with_matches =
      Enum.map(fields, fn({name, _type, _opts}) ->
        quote do
          {:ok, unquote(Macro.var(name, nil))} <- unquote(:"cast_#{name}")(params, opts)
        end
      end)

    with_ast = {:with, [], with_matches ++ [[do: with_body]]}

    make_ast =
      quote do
        def make(params, opts) do
          unquote(with_ast)
        end
      end

    merge_blocks(make_ast, cast_defs)
    |> tap(fn(ast) -> IO.puts(Macro.to_string(ast)) end)
  end

  defp merge_blocks(a, b) do
    {:__block__, [], block_content(a) ++ block_content(b)}
  end

  defp block_content({:__block__, [], content}) do
    content
  end

  defp block_content({_, _, _} = expr) do
    [expr]
  end

  defp block_content([]) do
    []
  end
end
