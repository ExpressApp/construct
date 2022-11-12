defmodule Construct.Compiler.AST do
  @moduledoc false

  def block(ast) do
    {:__block__, [], List.wrap(ast)}
  end

  def module_nest(module, name) do
    Module.concat(module, String.to_atom(Macro.camelize(to_string(name))))
  end

  def spec_struct(ast) do
    {:%, [],
      [
        {:__MODULE__, [], Elixir},
        {:%{}, [], ast}
      ]}
  end

  def spec_type(type, opts) do
    type = Construct.Compiler.AST.Types.spec(type)

    case Keyword.fetch(opts, :default) do
      {:ok, default} ->
        spec_type_default(type, default)

      :error ->
        type
    end
  end

  defp spec_type_default(type, default) do
    case {type, Construct.Compiler.AST.Types.typeof(default)} do
      {term, term} ->
        type

      {{:list, _, _} = type, {:list, [], []}} ->
        type

      {type, typeof_default} ->
        quote do
          unquote(type) | unquote(typeof_default)
        end
    end
  end
end
