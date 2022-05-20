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
        typeof_default = Construct.Compiler.AST.Types.typeof(default)

        if type == typeof_default do
          type
        else
          quote do: unquote(type) | unquote(typeof_default)
        end

      :error ->
        type
    end
  end
end
