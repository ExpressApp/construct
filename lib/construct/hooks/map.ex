defmodule Construct.Hooks.Map do
  defmacro __using__(_opts \\ []) do
    quote do
      structure_compile_hook :post do
        def make(params, opts) do
          with {:ok, term} <- super(params, opts) do
            {:ok, Map.from_struct(term)}
          end
        end

        defoverridable make: 2
      end
    end
  end
end
