defmodule Construct.Hooks.OmitDefault do
  defmacro __using__(_opts \\ []) do
    quote do
      structure_compile_hook :post do
        @omits Enum.reduce(@fields, [], fn({name, _type, opts}, acc) ->
          if Keyword.get(opts, :omit_default, true) do
            [{name, Keyword.get(opts, :default)} | acc]
          else
            acc
          end
        end)

        def make(params, opts) do
          with {:ok, term} <- super(params, opts) do
            term =
              Enum.reduce(@omits, Map.from_struct(term), fn({name, default}, term) ->
                case term do
                  %{^name => ^default} -> Map.delete(term, name)
                  %{} -> term
                end
              end)

            {:ok, term}
          end
        end

        def __omits__ do
          @omits
        end

        defoverridable make: 2
      end
    end
  end
end
