defmodule Construct.Integration.TypesOfTest do
  use Construct.TestCase

  defmodule CustomType do
    @behaviour Construct.Type

    def cast("test"), do: {:ok, :test}
    def cast(_), do: :error
  end

  defmodule Structure do
    use Construct do
      field :a do
        field :b do
          field :c, CustomType
          field :d, :string, default: "test"
        end
      end

      field :e
      field :f, :integer
      field :g, :float, default: 0.42
    end
  end

  test "returns map with types" do
    assert %{
      a: {%{b: {%{c: {CustomType, []}, d: {:string, [default: "test"]}}, []}}, []},
      e: {:string, []},
      f: {:integer, []},
      g: {:float, [default: 0.42]}
    } == Construct.types_of!(Structure)
  end

  test "returned types that behaves like original definition" do
    params = %{"a" => %{"b" => %{"c" => "test"}}, "e" => "str", "f" => 42}
    types = Construct.types_of!(Structure)

    assert {:ok, result1} = Construct.Cast.make(types, params)
    assert {:ok, result2} = Structure.make(params)

    assert result1 == deep_struct_to_map(result2)
  end

  test "returns error if provided module is not Construct definition" do
    assert_raise ArgumentError, "not a Construct definition", fn ->
      Construct.types_of!(__MODULE__)
    end
  end

  defp deep_struct_to_map(%{__struct__: _} = struct) do
    Enum.into(Map.from_struct(struct), %{}, fn
      ({k, v}) when is_map(v) -> {k, deep_struct_to_map(v)}
      ({k, v}) -> {k, v}
    end)
  end
  defp deep_struct_to_map(value) do
    value
  end
end
