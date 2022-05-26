defmodule Construct.Compiler do
  @moduledoc false

  alias Construct.Compiler
  alias Construct.Compiler.AST

  @registry Construct.Registry
  @no_default :__construct_no_default__

  def construct_module?(module) do
    registered_type?(module) || ensure_compiled?(module) && function_exported?(module, :__construct__, 1)
  end

  def collect_types(module) do
    Enum.into(module.__construct__(:types), %{}, fn({name, {type, opts}}) ->
      # check if type is not circular also
      if module != type && is_atom(type) && construct_module?(type) do
        {name, {collect_types(type), opts}}
      else
        {name, {type, opts}}
      end
    end)
  end

  def pre(opts) do
    {pre_ast, opts} =
      case Keyword.pop(opts, :do) do
        {nil, opts} ->
          {quote(do: import(Construct, only: [structure: 1, structure_compile_hook: 2])), opts}

        {ast, opts} ->
          {Construct.Compiler.define(ast), opts}
      end

    register_attributes_ast =
      quote do
        Module.register_attribute(__MODULE__, :fields, accumulate: true)
        Module.register_attribute(__MODULE__, :construct_fields, accumulate: true)
        Module.register_attribute(__MODULE__, :construct_fields_enforce, accumulate: true)
        Module.register_attribute(__MODULE__, :construct_compile_hook_pre, accumulate: true)
        Module.register_attribute(__MODULE__, :construct_compile_hook_post, accumulate: true)
      end

    {AST.block([register_attributes_ast, pre_ast]), opts}
  end

  def define(ast) do
    quote do
      Compiler.ensure_registry_started()
      Compiler.register_type(__MODULE__)

      Module.put_attribute(__MODULE__, :construct_defined, true)

      Module.eval_quoted(__ENV__, AST.block(
        Enum.reverse(Module.get_attribute(__MODULE__, :construct_compile_hook_pre))
      ))

      try do
        import Construct, only: [
          field: 1, field: 2, field: 3,
          include: 1, include: 2
        ]

        unquote(ast)
      after
        :ok
      end

      Module.eval_quoted(__ENV__, AST.block([
        Compiler.define_struct(@construct_fields, @construct_fields_enforce),
        Compiler.define_construct_functions(__ENV__, @fields),
        Compiler.define_typespec(@fields),
      ]))

      Module.eval_quoted(__ENV__, AST.block(
        Enum.reverse(Module.get_attribute(__MODULE__, :construct_compile_hook_post))
      ))
    end
  end

  def define_from_types({:%{}, _, types}) do
    Enum.reduce(Enum.reverse(types), [], fn
      ({name, {{:%{}, _, _} = types, opts}}, acc) ->
        [{:field, [], [name, opts, [do: AST.block(define_from_types(types))]]} | acc]

      ({name, {:%{}, _, _} = types}, acc) ->
        [{:field, [], [name, [], [do: AST.block(define_from_types(types))]]} | acc]

      ({name, {type, opts}}, acc) ->
        [{:field, [], [name, type, opts]} | acc]

      ({name, type}, acc) ->
        [{:field, [], [name, type, []]} | acc]

    end)
  end

  def define_struct(construct_fields, construct_fields_enforce) do
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
      enforce_keys = Keyword.get(@construct_opts, :enforce_keys, true)

      if enforce_keys do
        @enforce_keys Enum.uniq(unquote(enforce_fields))
      end

      defstruct unquote(Macro.escape(fields))
    end
  end

  def define_construct_functions(_env, fields) do
    types =
      fields
      |> Enum.reduce(%{}, fn({name, type, opts}, acc) -> Map.put_new(acc, name, {type, opts}) end)
      |> Macro.escape()

    quote do
      def __construct__(:types), do: unquote(types)
    end
  end

  def define_typespec(fields) do
    typespecs =
      Enum.map(fields, fn({name, type, opts}) ->
        {name, AST.spec_type(type, opts)}
      end)

    modulespec = AST.spec_struct(typespecs)

    quote do
      @type t :: unquote(modulespec)
    end
  end

  def define_field(module, name, type, opts) do
    _ = check_field_name!(name)
    k = check_type!(type)

    case default_value(k, type, opts) do
      @no_default ->
        put_attribute(module, :fields, {name, type, opts})
        put_attribute(module, :construct_fields, {name, nil})
        put_attribute(module, :construct_fields_enforce, name)

      term ->
        put_attribute(module, :fields, {name, type, Keyword.put(opts, :default, term)})
        put_attribute(module, :construct_fields, {name, term})
        pop_attribute(module, :construct_fields_enforce, name)

    end
  end

  def define_nested_field(name, ast, opts) do
    check_field_name!(name)

    quote do
      opts = unquote(opts)
      module_name = AST.module_nest(__MODULE__, unquote(name))

      derives_ast = Compiler.define_derive(__MODULE__, opts)
      definition_pre_ast = Compiler.define_definition(__MODULE__, :pre, :construct_compile_hook_pre)
      definition_post_ast = Compiler.define_definition(__MODULE__, :post, :construct_compile_hook_post)

      defmodule module_name do
        use Construct

        Module.eval_quoted(__ENV__, derives_ast)
        Module.eval_quoted(__ENV__, definition_pre_ast)
        Module.eval_quoted(__ENV__, definition_post_ast)

        structure do
          unquote(ast)
        end
      end

      Compiler.define_field(__MODULE__, unquote(name), module_name, opts)
    end
  end

  def define_definition(module, type, attribute) do
    case Module.get_attribute(module, attribute) do
      [] ->
        AST.block([])

      ls ->
        quote do
          structure_compile_hook unquote(type) do
            unquote(ls)
          end
        end
    end
  end

  def define_derive(module, opts) do
    derive = Keyword.get(opts, :derive, Module.get_attribute(module, :derive))
    construct_compile_hook_pre = Module.get_attribute(module, :construct_compile_hook_pre)

    if construct_compile_hook_pre == [] do
      quote do
        @derive unquote(derive)
      end
    end
  end

  def define_include(module, opts) do
    quote do
      module = unquote(module)

      opts = unquote(opts)
      only = Keyword.get(opts, :only)

      unless Compiler.construct_module?(module) do
        raise Construct.DefinitionError, "provided #{inspect(module)} is not Construct module"
      end

      types = module.__construct__(:types)

      types =
        if is_list(only) do
          Enum.each(only, fn(field) ->
            unless Map.has_key?(types, field) do
              raise Construct.DefinitionError,
                "field #{inspect(field)} in :only option " <>
                  "doesn't exist in #{inspect(module)}"
            end
          end)

          Map.take(types, only)
        else
          types
        end

      Enum.each(types, fn({name, {type, opts}}) ->
        Compiler.define_field(__MODULE__, name, type, opts)
      end)
    end
  end

  def define_structure_compile_hook(type, ast) do
    unless type in [:pre, :post] do
      raise Construct.DefinitionError, "structure_compile_hook type can be :pre or :past, but #{inspect(type)} given"
    end

    ast_escaped = Macro.escape(ast)

    quote do
      if Module.get_attribute(__MODULE__, :construct_defined) do
        raise Construct.DefinitionError, "structure_compile_hook should be defined before structure itself"
      end

      case unquote(type) do
        :pre ->
          Module.put_attribute(__MODULE__, :construct_compile_hook_pre, unquote(ast_escaped))

        :post ->
          Module.put_attribute(__MODULE__, :construct_compile_hook_post, unquote(ast_escaped))
      end
    end
  end

  def ensure_registry_started do
    case Agent.start(&MapSet.new/0, name: @registry) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      _ -> raise Construct.DefinitionError, "unexpected compilation error"
    end
  end

  def register_type(module) do
    Agent.update(@registry, &MapSet.put(&1, module))
  end

  def registered_type?(module) do
    Agent.get(@registry, &MapSet.member?(&1, module))
  catch
    :exit, _ -> false
  end

  ### internal functions

  defp put_attribute(module, key, value) do
    Module.put_attribute(module, key, value)
  end

  defp pop_attribute(module, key, value) do
    old = Module.get_attribute(module, key)
    Module.delete_attribute(module, key)

    Enum.each(List.delete(old, value), &(put_attribute(module, key, &1)))
  end

  defp check_type!({:array, type}) do
    check_type!(type)
    :builtin
  end

  defp check_type!({:map, type}) do
    check_type!(type)
    :builtin
  end

  defp check_type!({typec, _arg}) do
    check_typec_complex!(typec)
    :custom
  end

  defp check_type!(type_list) when is_list(type_list) do
    Enum.each(type_list, &check_type!/1)
    :builtin
  end

  defp check_type!(type) do
    if Construct.Type.primitive?(type) do
      :builtin
    else
      check_type_complex!(type)
    end
  end

  defp check_type_complex!(module) do
    if construct_module?(module) do
      :construct
    else
      unless ensure_compiled?(module) do
        raise Construct.DefinitionError, "undefined module #{inspect(module)}"
      end

      unless function_exported?(module, :cast, 1) do
        raise Construct.DefinitionError, "undefined function cast/1 for #{inspect(module)}"
      end

      :custom
    end
  end

  defp check_typec_complex!(module) do
    unless ensure_compiled?(module) do
      raise Construct.DefinitionError, "undefined module #{inspect(module)}"
    end

    unless function_exported?(module, :castc, 2) do
      raise Construct.DefinitionError, "undefined function castc/2 for #{inspect(module)}"
    end
  end

  defp check_field_name!(name) when is_atom(name) do
    :ok
  end

  defp check_field_name!(name) do
    raise Construct.DefinitionError, "expected atom for field name, got `#{inspect(name)}`"
  end

  defp default_value(kind, type, opts) do
    check_default!(make_default_value(kind, type, opts))
  end

  defp make_default_value(:builtin, _type, opts) do
    Keyword.get(opts, :default, @no_default)
  end

  defp make_default_value(:construct, type, opts) do
    case Keyword.get(opts, :default, @no_default) do
      @no_default ->
        if function_exported?(type, :default, 0) do
          &type.default/0
        else
          make_struct(type)
        end

      term ->
        term
    end
  end

  defp make_default_value(:custom, {type, _}, opts) do
    make_default_value(:custom, type, opts)
  end

  defp make_default_value(:custom, type, opts) do
    case Keyword.get(opts, :default, @no_default) do
      @no_default ->
        if function_exported?(type, :default, 0) do
          &type.default/0
        else
          @no_default
        end

      term ->
        term
    end
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

  defp make_struct(module) do
    module.make!()
  rescue
    [Construct.MakeError, UndefinedFunctionError] -> @no_default
  end

  defp ensure_compiled?(module) do
    Code.ensure_compiled(module) == {:module, module}
  end
end
