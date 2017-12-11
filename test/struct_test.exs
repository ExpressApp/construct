defmodule StructTest do
  use ExUnit.Case

  defmodule Embedded do
    use Struct

    structure do
      field :a, :integer
      field :b, :string
    end
  end

  defmodule Data do
    use Struct

    structure do
      field :name, :string
      field :age, :integer, default: 18
      field :friends, {:array, :string}, default: nil
      field :data, :any, default: nil
      field :data_map, {:map, :string}, default: nil
      field :embedded, Embedded, default: nil
      field :embeddeds, {:array, Embedded}, default: nil
      field :raw_map, :map, default: nil
    end
  end

  defmodule Default do
    use Struct

    structure do
      field :hash, :map, default: %{}
    end
  end

  defmodule CustomType do
    def cast(value) when is_list(value) do
      {:ok, value}
    end
    def cast(_) do
      {:error, :invalid_custom_list}
    end
  end

  defmodule StructWithCustomType do
    use Struct

    structure do
      field :list, CustomType
    end
  end

  defmodule EctoTypeCast do
    def cast(value) when is_binary(value) do
      {:ok, value}
    end
    def cast(_value) do
      :error
    end
  end

  defmodule EctoCast do
    use Struct

    structure do
      field :name, EctoTypeCast
    end
  end

  defmodule InPlaceNested do
    use Struct

    structure do
      field :nested do
        field :a, :string
        field :b, CustomType
      end
    end
  end

  defmodule InPlaceNestedWithOpts do
    use Struct

    structure do
      field :nested, [default: %{}] do
        field :a, :string
        field :b, CustomType
      end
    end
  end

  defmodule StructWithOpts do
    use Struct, make_map: true, empty_values: [nil, ""]

    structure do
      field :a, :string
    end
  end

  defmodule Include do
    use Struct

    structure do
      include Data
      include InPlaceNestedWithOpts
    end
  end

  describe "creates when" do
    test "params are valid" do
      assert {:ok, %Data{name: "test", age: 10}}
          == make(%{name: "test", age: 10})
    end

    test "params made from self" do
      assert {:ok, %Data{name: "test", age: 18}}
          == make(%Data{name: "test"})
    end

    test "array is passed" do
      assert {:ok, %Data{name: "test", friends: ["test"]}}
          == make(%{name: "test", friends: ["test"]})
    end

    test "map is passed" do
      assert {:ok, %Data{name: "test", data_map: %{a: "string", b: "2"}}}
          == make(%{name: "test", data_map: %{a: "string", b: "2"}})
    end

    test "any fields is passed" do
      assert {:ok, %Data{name: "john", data: "test"}}
          == make(%{name: "john", data: "test"})
      assert {:ok, %Data{name: "john", data: %{}}}
          == make(%{name: "john", data: %{}})
    end

    test "embedded field is passed" do
      assert {:ok, %Data{name: "john", embedded: %Embedded{a: 1, b: ""}}}
           == make(%{name: "john", embedded: %{a: 1, b: ""}})
      assert {:ok, %{name: "john", age: 18, data: nil, data_map: nil, embeddeds: nil,
                     friends: nil, raw_map: nil, embedded: %{a: 1, b: ""}}}
          == make(%{name: "john", embedded: %{a: 1, b: ""}}, make_map: true)
    end

    test "embeddeds field is passed" do
      assert {:ok, %Data{name: "john", embeddeds: [%Embedded{a: 1, b: ""}]}}
          == make(%{name: "john", embeddeds: [%{a: 1, b: ""}]})
      assert {:ok, %{name: "john", age: 18, data: nil, data_map: nil, embedded: nil,
                     friends: nil, raw_map: nil, embeddeds: [%{a: 1, b: ""}]}}
          == make(%{name: "john", embeddeds: [%{a: 1, b: ""}]}, make_map: true)
    end

    test "raw_map field is passed" do
      assert {:ok, %Data{name: "john", raw_map: %{a: 1, b: ""}}}
          == make(%{name: "john", raw_map: %{a: 1, b: ""}})
    end

    test "field with default value is missing" do
      assert {:ok, %Data{name: "test", age: 18}}
          == make(%{name: "test"})
    end

    test "default hash" do
      assert {:ok, %Default{hash: %{}}}
          == Default.make()
    end

    test "custom type is valid" do
      assert {:ok, %StructWithCustomType{list: []}}
          == StructWithCustomType.make(%{list: []})
    end

    test "with in place nested fields" do
      assert {:ok, %InPlaceNested{nested: %InPlaceNested.Nested{a: "a", b: []}}}
          == InPlaceNested.make(%{nested: %{a: "a", b: []}})
    end

    test "with in place nested fields and opts" do
      assert {:ok, %InPlaceNestedWithOpts{nested: %{}}}
          == InPlaceNestedWithOpts.make(%{})
    end

    test "with opts" do
      assert {:ok, %{a: "what"}} == StructWithOpts.make(%{a: "what"})
    end

    test "include" do
      map_fields = fn(struct) -> struct |> Map.from_struct |> Map.keys end

      assert Enum.sort(map_fields.(%Include{}))
          == Enum.sort(map_fields.(%Data{}) ++ map_fields.(%InPlaceNestedWithOpts{}))
    end
  end

  describe "error when" do
    test "name is missing (doesn't have default value)" do
      assert {:error, %{name: :missing}}
          == make(%{age: 10})
    end

    test "name is invalid when passed as nil" do
      assert {:error, %{name: :invalid}}
          == make(%{name: nil})
    end

    test "embedded field is invalid (missing some keys)" do
      assert {:error, %{embedded: %{a: :missing, b: :missing}}}
          == make(%{name: "john", embedded: %{}})
    end

    test "embeddeds field is invalid (missing some keys)" do
      assert {:error, %{embeddeds: %{a: :missing, b: :missing}}}
          == make(%{name: "john", embeddeds: [%{}]})
    end

    test "passed value in empty_values" do
      assert {:error, %{a: :missing}} == StructWithOpts.make(%{a: nil})
      assert {:error, %{a: :missing}} == StructWithOpts.make(%{a: ""})
    end

    test "tries to pass map with mixed keys type" do
      assert_raise(Struct.CastError, fn ->
        make(%{"name" => "john", age: 10})
      end)
    end

    test "tries to provide function in default value" do
      assert_raise(Struct.DefinitionError, fn ->
        defmodule Err do
          use Struct

          structure do
            field :err, :integer, default: fn -> 42 end
          end
        end
      end)
    end

    test "MakeError" do
      assert_raise(Struct.MakeError, "%{name: :missing}", fn ->
        Data.make!(%{})
      end)
    end

    test "custom type is invalid" do
      assert {:error, %{list: :invalid_custom_list}}
          == StructWithCustomType.make(%{list: "what"})
    end

    test "custom type (like Ecto types) is invalid" do
      assert {:error, %{name: :invalid}}
          == EctoCast.make(%{name: :test})
    end
  end

  def make(params, opts \\ []) do
    Data.make(params, opts)
  end
end
