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
  @no_default :__construct_no_default__

  # elixir 1.9.0 do not raise deadlocks for Code.ensure_compiled/1
  @no_raise_on_deadlocks Version.compare(System.version(), "1.9.0") != :lt

  @doc false
  defmacro __using__(opts \\ [])

  defmacro __using__({:%{}, _, _} = types) do
    quote do
      use Construct do
        unquote(__ast_from_types__(types))
      end
    end
  end

  defmacro __using__(opts) when is_list(opts) do
    {definition, opts} = Keyword.pop(opts, :do)

    pre_ast =
      if definition do
        defstructure(definition)
      else
        quote do
          import Construct, only: [structure: 1]
        end
      end

    quote do
      @behaviour Construct

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

      defoverridable make: 2
    end
  end

  @doc """
  Defines a structure.
  """
  defmacro structure([do: block]) do
    defstructure(block)
  end

  defp defstructure(block) do
    quote do
      import Construct

      Construct.__ensure_type_checker_started__()
      Construct.__register_as_complex_type__(__MODULE__)

      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :construct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :construct_fields_enforce, accumulate: true)

      unquote(block)

      Module.eval_quoted __ENV__, {:__block__, [], [
        Construct.__defstruct__(@construct_fields, @construct_fields_enforce),
        Construct.__types__(@fields),
        Construct.__typespecs__(@fields)]}
    end
  end

  @doc """
  Includes provided structure and checks definition for validity at compile-time.

  If included structure is invalid for some reason — this macro throws an
  `Struct.DefinitionError` exception with detailed reason.
  """
  @spec include(t) :: Macro.t()
  defmacro include(struct) do
    quote do
      module = unquote(struct)

      unless Construct.__is_construct_module__(module) do
        raise Construct.DefinitionError, "provided #{inspect(module)} is not Construct module"
      end

      Enum.each(module.__construct__(:types), fn({name, {type, opts}}) ->
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
  @spec field(atom, Construct.Type.t, Keyword.t) :: Macro.t()
  defmacro field(name, type \\ :string, opts \\ [])
  defmacro field(name, opts, [do: _] = contents) do
    make_nested_field(name, contents, opts)
  end
  defmacro field(name, [do: _] = contents, _opts) do
    make_nested_field(name, contents, [])
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
  @callback make!(params :: map, opts :: Keyword.t) :: t

  @doc """
  Alias to `c:make/2`, used to follow `c:Construct.Type.cast/1` callback.

  To use this structure as custom type.
  """
  @callback cast(params :: map, opts :: Keyword.t) :: {:ok, t} | {:error, term}

  @doc """
  Collects types from defined Construct module to map
  """
  def types_of!(module) do
    if construct_definition?(module) do
      deep_collect_construct_types(module)
    else
      raise ArgumentError, "not a Construct definition"
    end
  end

  defp deep_collect_construct_types(module) do
    Enum.into(module.__construct__(:types), %{}, fn({name, {type, opts}}) ->
      # check if type is not circular also
      if module != type && is_atom(type) && construct_definition?(type) do
        {name, {deep_collect_construct_types(type), opts}}
      else
        {name, {type, opts}}
      end
    end)
  end

  @doc """
  Checks if provided module is Construct definition
  """
  def construct_definition?(module) do
    ensure_compiled?(module) && function_exported?(module, :__construct__, 1)
  end

  @doc false
  def __ast_from_types__({:%{}, _, types}) do
    Enum.reduce(Enum.reverse(types), [], fn
      ({name, {{:%{}, _, _} = types, opts}}, acc) ->
        [{:field, [], [name, opts, [do: {:__block__, [], __ast_from_types__(types)}]]} | acc]

      ({name, {:%{}, _, _} = types}, acc) ->
        [{:field, [], [name, [], [do: {:__block__, [], __ast_from_types__(types)}]]} | acc]

      ({name, {type, opts}}, acc) ->
        [{:field, [], [name, type, opts]} | acc]

      ({name, type}, acc) ->
        [{:field, [], [name, type, []]} | acc]

    end)
  end

  @doc false
  def __defstruct__(construct_fields, construct_fields_enforce) do
    {fields, enforce_fields} =
      Enum.reduce(construct_fields, {[], construct_fields_enforce}, fn
        ({key, value}, {fields, enforce}) when is_function(value) ->
          {[{key, nil} | fields], [key | enforce]}

        (field, {fields, enforce}) ->
          {[field | fields], enforce}

      end)

    fields =
      fields
      |> Enum.reverse()
      |> Enum.uniq_by(fn({k, _}) -> k end)
      |> Enum.reverse()

    quote do
      @enforce_keys unquote(enforce_fields)
      defstruct unquote(Macro.escape(fields))
    end
  end

  @doc false
  def __types__(fields) do
    fields = Enum.uniq_by(fields, fn({k, _v, _opts}) -> k end)

    types =
      fields
      |> Enum.into(%{}, fn({name, type, opts}) -> {name, {type, opts}} end)
      |> Macro.escape

    quote do
      def __construct__(:types), do: unquote(types)
    end
  end

  @doc false
  def __typespecs__(fields) do
    typespecs =
      Enum.map(fields, fn({name, type, opts}) ->
        type = Construct.Type.spec(type)

        type =
          case Keyword.fetch(opts, :default) do
            {:ok, default} ->
              typeof_default = Construct.Type.typeof(default)

              if type == typeof_default do
                type
              else
                quote do: unquote(type) | unquote(typeof_default)
              end

            :error ->
              type
          end

        {name, type}
      end)

    modulespec =
      {:%, [],
        [
          {:__MODULE__, [], Elixir},
          {:%{}, [], typespecs}
        ]}

    quote do
      @type t :: unquote(modulespec)
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    check_field_name!(name)
    check_type!(type)

    case default_for_struct(type, opts) do
      @no_default ->
        Module.put_attribute(mod, :fields, {name, type, opts})
        Module.put_attribute(mod, :construct_fields, {name, nil})
        Module.put_attribute(mod, :construct_fields_enforce, name)

      default ->
        Module.put_attribute(mod, :fields, {name, type, Keyword.put(opts, :default, default)})
        Module.put_attribute(mod, :construct_fields, {name, default})
        pop_attribute(mod, :construct_fields_enforce, name)

    end
  end

  @doc false
  def __ensure_type_checker_started__ do
    case Agent.start(fn -> MapSet.new end, name: @type_checker_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      _ -> raise Construct.DefinitionError, "unexpected compilation error"
    end
  end

  @doc false
  def __register_as_complex_type__(module) do
    Agent.update(@type_checker_name, &MapSet.put(&1, module))
  end

  @doc false
  def __is_construct_module__(module) do
    construct_module?(module)
  end

  defp make_nested_field(name, contents, opts) do
    check_field_name!(name)

    nested_module_name = String.to_atom(Macro.camelize(Atom.to_string(name)))

    quote do
      opts = unquote(opts)

      current_module_name_ast =
        __MODULE__
        |> Atom.to_string()
        |> String.split(".")
        |> Enum.map(&String.to_atom/1)

      derives = Keyword.get(opts, :derive, Module.get_attribute(__MODULE__, :derive))

      current_module_ast =
        {:__aliases__, [alias: false], current_module_name_ast ++ [unquote(nested_module_name)]}
        |> Macro.expand(__ENV__)

      defmodule current_module_ast do
        @derive derives

        use Construct do
          unquote(contents)
        end
      end

      Construct.__field__(__MODULE__, unquote(name), current_module_ast, opts)
    end
  end

  defp pop_attribute(mod, key, value) do
    old = Module.get_attribute(mod, key)
    Module.delete_attribute(mod, key)

    Enum.each(old -- [value], &Module.put_attribute(mod, key, &1))
  end

  defp check_type!({:array, type}) do
    check_type!(type)
  end
  defp check_type!({:map, type}) do
    check_type!(type)
  end
  defp check_type!({typec, _arg}) do
    check_typec_complex!(typec)
  end
  defp check_type!(type_list) when is_list(type_list) do
    Enum.each(type_list, &check_type!/1)
  end
  defp check_type!(type) do
    unless Construct.Type.primitive?(type), do: check_type_complex!(type)
  end

  defp check_type_complex!(module) do
    check_type_complex!(module, {:cast, 1})
  end

  defp check_typec_complex!(module) do
    check_type_complex!(module, {:castc, 2})
  end

  defp check_type_complex!(module, {f, a}) do
    unless construct_module?(module) do
      unless ensure_compiled?(module) do
        raise Construct.DefinitionError, "undefined module #{inspect(module)}"
      end

      unless function_exported?(module, f, a) do
        raise Construct.DefinitionError, "undefined function #{f}/#{a} for #{inspect(module)}"
      end
    end
  end

  defp check_field_name!(name) when is_atom(name) do
    :ok
  end
  defp check_field_name!(name) do
    raise Construct.DefinitionError, "expected atom for field name, got `#{inspect(name)}`"
  end

  defp default_for_struct(maybe_module, opts) when is_atom(maybe_module) do
    case check_default!(Keyword.get(opts, :default, @no_default)) do
      @no_default -> try_to_make_struct_instance(maybe_module)
      val -> val
    end
  end
  defp default_for_struct(_, opts) do
    check_default!(Keyword.get(opts, :default, @no_default))
  end

  defp check_default!(default) when is_function(default, 0) do
    default
  end
  defp check_default!(default) when is_function(default) do
    raise Construct.DefinitionError, "functions in default values should be zero-arity"
  end
  defp check_default!(default) do
    default
  end

  defp try_to_make_struct_instance(module) do
    if construct_module?(module) do
      make_struct(module)
    else
      @no_default
    end
  end

  defp make_struct(module) do
    struct!(module)
  rescue
    [ArgumentError, UndefinedFunctionError] -> @no_default
  end

  defp construct_module?(module) do
    if @no_raise_on_deadlocks, do: Code.ensure_compiled(module)

    Agent.get(@type_checker_name, &MapSet.member?(&1, module)) ||
      ensure_compiled?(module) && function_exported?(module, :__construct__, 1)
  end

  defp ensure_compiled?(module) do
    case Code.ensure_compiled(module) do
      {:module, _} -> true
      {:error, _} -> false
    end
  end
end
