defmodule Struct do
  defmacro __using__(_opts) do
    quote do
      import Struct, only: [structure: 1]

      def make(params \\ %{}, opts \\ []) do
        Struct.Cast.make(__MODULE__, params, opts)
      end

      def make!(params \\ %{}, opts \\ []) do
        case make(params, opts) do
          {:ok, struct} -> struct
          {:error, reason} -> raise Struct.MakeError, reason
        end
      end

      def cast(params) do
        case make(params) do
          {:ok, struct} -> {:ok, struct}
          {:error, _reason} -> :error
        end
      end

      defoverridable make: 2
    end
  end

  defmacro structure([do: block]) do
    quote do
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)

      try do
        import Struct
        unquote(block)
      after
        :ok
      end

      struct_fields = Enum.reverse(@struct_fields)
      fields = Enum.reverse(@fields)

      Module.eval_quoted __ENV__, [
        Struct.__defstruct__(struct_fields),
        Struct.__types__(fields)]
    end
  end

  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      Struct.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc false
  def __defstruct__(struct_fields) do
    quote do
      defstruct unquote(Macro.escape(struct_fields))
    end
  end

  @doc false
  def __types__(fields) do
    quoted =
      Enum.map(fields, fn({name, type, opts}) ->
        quote do
          def __schema__(:type, unquote(name)) do
            {unquote(Macro.escape(type)), unquote(Macro.escape(opts))}
          end
        end
      end)

    types =
      fields
      |> Enum.into(%{}, fn({name, type, _default}) -> {name, type} end)
      |> Macro.escape

    quote do
      def __schema__(:types), do: unquote(types)
      unquote(quoted)
      def __schema__(:type, _), do: nil
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    check_type!(name, type)

    Module.put_attribute(mod, :fields, {name, type, opts})
    Module.put_attribute(mod, :struct_fields, {name, default_for_struct(opts)})
  end

  def default_for_struct(opts) do
    check_default!(Keyword.get(opts, :default))
  end

  defp check_type!(_name, _type) do
    :ok
  end

  def check_default!(default) when is_function(default) do
    raise Struct.DefinitionError, "default value cannot to be a function"
  end
  def check_default!(default) do
    default
  end
end
