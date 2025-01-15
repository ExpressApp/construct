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

  @doc """
  Alias to `Construct.Cast.make/3`.
  """
  @callback make(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  @doc """
  Alias to `c:make/2`, but raises an `Construct.MakeError` exception if params have errors.
  """
  @callback make!(params :: map, opts :: Keyword.t) :: t

  @doc """
  Alias to `c:make/2`, used to follow `c:Construct.Type.cast/1` callback.

  To use this structure as custom type.
  """
  @callback cast(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  @doc false
  defmacro __using__(opts \\ [])

  defmacro __using__({:%{}, _, _} = types) do
    quote do
      use Construct do
        unquote(Construct.Compiler.define_from_types(types))
      end
    end
  end

  defmacro __using__(opts) when is_list(opts) do
    {pre_ast, opts} = Construct.Compiler.pre(opts)

    quote do
      @behaviour Construct
      @construct_opts unquote(opts)

      unquote(pre_ast)

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

      defoverridable make: 2, cast: 2
    end
  end

  @doc """
  Defines a structure.
  """
  defmacro structure([do: ast]) do
    Construct.Compiler.define(ast)
  end

  @doc """
  Includes provided structure and checks definition for validity at compile-time.

  ## Options

    * `:only` - (integer) specify fields that should be taken from included module,
      throws an error when field doesn't exist in provided module.

  If included structure is invalid for some reason — this macro throws an
  `Construct.DefinitionError` exception with detailed reason.
  """
  @spec include(t, keyword) :: Macro.t()
  defmacro include(module, opts \\ []) do
    Construct.Compiler.define_include(module, opts)
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
  @spec field(atom(), Construct.Type.t(), Keyword.t()) :: Macro.t()
  defmacro field(name, type \\ :string, opts \\ [])

  defmacro field(name, opts, [do: _] = ast) do
    Construct.Compiler.define_nested_field(name, ast, opts)
  end

  defmacro field(name, [do: _] = ast, _opts) do
    Construct.Compiler.define_nested_field(name, ast, [])
  end

  defmacro field(name, type, opts) do
    quote do
      Construct.Compiler.define_field(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc """
  No doc at this time, should be written for 3.0.0 release
  """
  defmacro structure_compile_hook(type, [do: ast]) do
    Construct.Compiler.define_structure_compile_hook(type, ast)
  end

  @doc """
  Collect types from defined Construct module to map
  """
  def types_of!(module) do
    if construct?(module) do
      Construct.Compiler.collect_types(module)
    else
      raise ArgumentError, "not a Construct definition"
    end
  end

  @doc """
  Checks if provided module is Construct module
  """
  def construct?(module) do
    Construct.Compiler.construct_module?(module)
  end
end
