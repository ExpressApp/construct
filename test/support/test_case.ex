defmodule Struct.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Struct.TestCase

      def make({:module, _, _, _} = mod, params, opts \\ []) do
        name(mod).make(params, opts)
      end

      def make!({:module, _, _, _} = mod, params, opts \\ []) do
        name(mod).make!(params, opts)
      end

      def name({:module, module, _beam, _attributes}) do
        module
      end
    end
  end

  defmacro create_struct([do: block]) do
    __create_struct__([], block)
  end

  defmacro create_struct(opts, [do: block]) do
    __create_struct__(opts, block)
  end

  def __create_struct__(opts, block) do
    quote do
      # retrieve module name from test case and line
      name = __ENV__.module
      line = __ENV__.line

      module_name = :"#{name}_#{line}"

      defmodule module_name do
        use Struct, unquote(opts)

        structure do
          unquote(block)
        end
      end
    end
  end
end
