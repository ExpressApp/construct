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

    test "embeddeds field is passed" do
      assert {:ok, %Data{name: "john", embeddeds: [%Embedded{a: 1, b: "", c: [42, 1.1]}]}}
          == make(%{name: "john", embeddeds: [%{a: 1, b: "", c: [42, 1.1]}]})
    end

    test "raw_map field is passed" do
      assert {:ok, %Data{name: "john", raw_map: %{a: 1, b: "", c: [42, 1.1]}}}
          == make(%{name: "john", raw_map: %{a: 1, b: "", c: [42, 1.1]}})
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

    test "custom type is valid" do
      assert {:ok, %StructWithCustomType{list: []}}
          == StructWithCustomType.make(%{list: []})
    end
  end

  describe "error when" do
    test "name is missing but required by default" do
      assert {:error, %{name: :missing}}
          == make(%{age: 10})
    end

    test "embedded field is invalid" do
      assert {:error, %{embedded: %{a: :missing, b: :missing, c: :missing}}}
          == make(%{name: "john", embedded: %{}})
    end

    test "embeddeds field is invalid" do
      assert {:error, %{embeddeds: %{a: :missing, b: :missing, c: :missing}}}
          == make(%{name: "john", embeddeds: [%{}]})
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
