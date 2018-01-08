defmodule Construct do
  @moduledoc """
  Construct internally divided into three components:

    * `Construct` — defining structures;
    * `Construct.Cast` — making structure instances;
    * `Construct.Type` — type-coercion and custom type behaviour.

  ## Construct definition

      defmodule StructureName do
        use Construct, struct_opts

        structure do
          include AnotherStructure
          field name, type, options
        end
      end

  `struct_opts` is options passed to `c:make/2` and `c:make!/2`, described in `Construct.Cast.make/3`.

  When you type `use Construct` — library bootstrapped few functions with `Construct` behaviour:

    * `c:make/2` — just an alias to `Construct.Cast.make/3`;
    * `c:make!/2` — alias to `c:make/2` but throws `Construct.MakeError` exception if provided params are invalid;
    * `c:cast/2` — alias to `c:make/2` too, for follow `Construct.Type` behaviour and use defined structure as type.
  """

  @type t :: struct
  @type_checker_name Construct.TypeRegistry

  @doc false
  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Construct

      import Construct, only: [structure: 1]

      @type t :: %__MODULE__{}

      def make(params \\ %{}, opts \\ []) do
        Construct.Cast.make(__MODULE__, params, Keyword.merge(opts, unquote(opts)))
      end

      def make!(params \\ %{}, opts \\ []) do
        case make(params, opts) do
          {:ok, structure} -> structure
          {:error, reason} -> raise Construct.MakeError, %{reason: reason, params: params}
        end
      end

      def cast(params, opts \\ []) do
        make(params, opts)
      end

      defoverridable make: 2
    end
  end

  @doc """
  Defines a structure.
  """
  defmacro structure([do: block]) do
    quote do
      import Construct

      Construct.__register_as_complex_type__(__MODULE__)

      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :construct_fields, accumulate: true)

      unquote(block)

      Module.eval_quoted __ENV__, [
        Construct.__defstruct__(@construct_fields),
        Construct.__types__(@fields)]
    end
  end

  @doc """
  Includes provided structure and checks definition for validity at compile-time.

  If included structure is invalid for some reason — this macro throws an
  `Struct.DefinitionError` exception with detailed reason.
  """
  @spec include(t) :: :ok
  defmacro include(struct) do
    quote do
      module = unquote(struct)

      unless Code.ensure_compiled?(module) do
        raise Construct.DefinitionError, "undefined module #{module}"
      end

      unless function_exported?(module, :__structure__, 1) do
        raise Construct.DefinitionError, "provided #{module} is not Construct module"
      end

      type_defs = module.__structure__(:types)

      Enum.each(type_defs, fn({name, _type}) ->
        {type, opts} = module.__structure__(:type, name)
        Construct.__field__(__MODULE__, name, type, opts)
      end)
    end
  end

  @doc """
  Defines field on the structure with given name, type and options.

  Checks definition validity at compile time by name, type and options.
  For custom types checks for module existence and `c:Construct.Type.cast/1` callback.

  If field definition is invalid for some reason — it throws an `Construct.DefinitionError`
  exception with detailed reason.

  ## Options

    * `:default` — sets default value for that field:

      * The default value is calculated at compilation time, so don't use expressions like
        DateTime.utc_now or Ecto.UUID.generate as they would then be the same for all structures;

      * Value from params is compared with default value before and after type cast;

      * If you pass `field :a, type, default: nil` and `make(%{a: nil})` — type coercion will
        not be used, `nil` compares with default value and just appends that value to structure;

      * If field doesn't exist in params, it will use default value.

      By default this option is unset. Notice that you can't use functions as a default value.
  """
  @spec field(atom, Construct.Type.t, Keyword.t) :: :ok
  defmacro field(name, type \\ :string, opts \\ [])
  defmacro field(name, opts, [do: _] = contents) do
    __make_nested_field__(name, contents, opts)
  end
  defmacro field(name, [do: _] = contents, _opts) do
    __make_nested_field__(name, contents, [])
  end
  defmacro field(name, type, opts) do
    quote do
      Construct.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc """
  Alias to `Construct.Cast.make/3`.
  """
  @callback make(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  @doc """
  Alias to `c:make/2`, but raises an `Construct.MakeError` exception if params have errors.
  """
  @callback make!(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  @doc """
  Alias to `c:make/2`, used to follow `c:Construct.Type.cast/1` callback.

  To use this structure as custom type.
  """
  @callback cast(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  defp __make_nested_field__(name, contents, opts) do
    check_field_name!(name)

    nested_module_name = String.to_atom(Macro.camelize(Atom.to_string(name)))

    quote do
      current_module_name_ast =
        __MODULE__
        |> Atom.to_string()
        |> String.split(".")
        |> Enum.map(&String.to_atom/1)

      current_module_ast =
        {:__aliases__, [alias: false], current_module_name_ast ++ [unquote(nested_module_name)]}
        |> Macro.expand(__ENV__)

      defmodule current_module_ast do
        use Construct
        structure do: unquote(contents)
      end

      Construct.__field__(__MODULE__, unquote(name), current_module_ast, unquote(opts))
    end
  end

  @doc false
  def __defstruct__(construct_fields) do
    quote do
      defstruct unquote(Macro.escape(construct_fields))
    end
  end

  @doc false
  def __types__(fields) do
    quoted =
      Enum.map(fields, fn({name, type, opts}) ->
        quote do
          def __structure__(:type, unquote(name)) do
            {unquote(Macro.escape(type)), unquote(Macro.escape(opts))}
          end
        end
      end)

    types =
      fields
      |> Enum.into(%{}, fn({name, type, _default}) -> {name, type} end)
      |> Macro.escape

    quote do
      def __structure__(:types), do: unquote(types)
      unquote(quoted)
      def __structure__(:type, _), do: nil
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    check_field_name!(name)
    check_type!(type)

    Module.put_attribute(mod, :fields, {name, type, opts})
    Module.put_attribute(mod, :construct_fields, {name, default_for_struct(opts)})
  end


  @doc """
  This function register module as a valid Construct type. This allows compile-time type checks
  """
  def __register_as_complex_type__(module) do
    case Agent.start(fn -> MapSet.new end, name: @type_checker_name) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      _ -> raise Construct.DefinitionError, "unexpected compilation error"
    end
    |> Agent.update(&MapSet.put(&1, module))
  end

  defp check_type!({:array, type}) do
    unless Construct.Type.primitive?(type), do: check_type_complex!(type)
  end
  defp check_type!({:map, type}) do
    unless Construct.Type.primitive?(type), do: check_type_complex!(type)
  end
  defp check_type!({complex, _}) do
    raise Construct.DefinitionError, "undefined complex type #{inspect(complex)}"
  end
  defp check_type!(type_list) when is_list(type_list) do
    Enum.each(type_list, &check_type!/1)
  end
  defp check_type!(type) do
    unless Construct.Type.primitive?(type), do: check_type_complex!(type)
  end

  defp check_type_complex!(module) do
    case Agent.start(fn -> MapSet.new end, name: @type_checker_name) do
      {:ok, _} ->
        raise Construct.DefinitionError, "type checker crashed unexpectedly"
      {:error, {:already_started, _}} ->
        case Agent.get(@type_checker_name, &MapSet.member?(&1, module)) do
          true -> :ok
          _ ->
            case Code.ensure_compiled?(module) do
              false -> raise Construct.DefinitionError, "undefined module #{module}"
              _ ->
                case function_exported?(module, :cast, 1) do
                  true -> :ok
                  _ -> raise Construct.DefinitionError, "undefined function cast/1 for #{module}"
                end
            end
        end
      _ -> raise Construct.DefinitionError, "unexpected compilation error"
    end
  end

  defp check_field_name!(name) when is_atom(name), do: :ok
  defp check_field_name!(name), do: raise Construct.DefinitionError, "expected atom for field name, got `#{inspect(name)}`"

  defp default_for_struct(opts), do: check_default!(Keyword.get(opts, :default))

  defp check_default!(default) when is_function(default), do: raise Construct.DefinitionError, "default value cannot to be a function"
  defp check_default!(default), do: default
end
