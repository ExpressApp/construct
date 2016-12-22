defmodule StructTest do
  use ExUnit.Case

  defmodule Embedded do
    use Struct

    structure do
      field :a, :integer
      field :b, :string
      field :c, {:array, [:integer, :float]}
    end
  end

  defmodule Data do
    use Struct

    structure do
      field :name, :string
      field :age, :integer, default: 18
      field :friends, {:array, [:map, :string]}, default: nil
      field :body, [:map, :string], required: false
      field :data, :any, default: nil
      field :data_map, {:map, [:string, :integer]}, default: nil
      field :embedded, Embedded, default: nil
    end
  end

  defmodule Default do
    use Struct

    structure do
      field :hash, :map, default: %{}
    end
  end

  describe "creates when" do
    test "params are valid" do
      assert {:ok, %Data{name: "test", age: 10}}
          == make(%{name: "test", age: 10})
    end

    test "array is passed" do
      assert {:ok, %Data{name: "test", friends: ["test"]}}
          == make(%{name: "test", friends: ["test"]})
    end

    test "map is passed" do
      assert {:ok, %Data{name: "test", data_map: %{a: "string", b: 2}}}
          == make(%{name: "test", data_map: %{a: "string", b: 2}})
    end

    test "any fields is passed" do
      assert {:ok, %Data{name: "john", data: "test"}}
          == make(%{name: "john", data: "test"})
      assert {:ok, %Data{name: "john", data: %{}}}
          == make(%{name: "john", data: %{}})
    end

    test "embedded field is passed" do
      assert {:ok, %Data{name: "john", embedded: %Embedded{a: 1, b: "", c: [42, 1.1]}}}
          == make(%{name: "john", embedded: %{a: 1, b: "", c: [42, 1.1]}})
    end

    test "field with default value is missing" do
      assert {:ok, %Data{name: "test", age: 18}}
          == make(%{name: "test"})
    end

    test "field have ambiguous type" do
      assert {:ok, %Data{name: "test", age: 18, body: "string"}}
          == make(%{name: "test", body: "string"})
      assert {:ok, %Data{name: "test", age: 18, body: %{map: "valid"}}}
          == make(%{name: "test", body: %{map: "valid"}})
    end

    test "default hash" do
      assert {:ok, %Default{hash: %{}}}
          == Default.make()
    end
  end

  describe "error when" do
    test "name is missing but required by default" do
      assert {:error, [name: :missing]}
          == make(%{age: 10})
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
  end

  def make(params, opts \\ []) do
    Data.make(params, opts)
  end
end
