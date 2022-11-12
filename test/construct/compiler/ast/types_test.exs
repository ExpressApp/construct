defmodule Construct.Compiler.AST.TypesTest do
  use ExUnit.Case

  alias Construct.Compiler.AST.Types

  defmodule TestType do
    use Construct do
      field :a
    end
  end

  defmodule TestModule do
  end

  describe "#typeof" do
    test "for custom types" do
      assert "Construct.Compiler.AST.TypesTest.TestType.t()" == typeof(TestType)
      assert "atom()" == typeof(TestModule)
      assert "atom()" == typeof(:ok)
    end
  end

  defp typeof(term) do
    term |> Types.typeof() |> Macro.to_string()
  end
end
