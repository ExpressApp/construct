defmodule Construct.Integration.BuildTest do
  use Construct.TestCase

  test "use/2 creates make/0,1,2 make!/0,1,2 and cast/1,2" do
    module = create_construct do
      field :key
    end

    module_name = name(module)

    Enum.each(0..2, fn(arity) ->
      assert function_exported?(module_name, :make, arity)
    end)

    Enum.each(0..2, fn(arity) ->
      assert function_exported?(module_name, :make!, arity)
    end)

    Enum.each(1..2, fn(arity) ->
      assert function_exported?(module_name, :cast, arity)
    end)
  end

  test "pass `empty_values` to use/2" do
    module = create_construct [empty_values: ["empty_val"]] do
      field :a
    end

    assert {:ok, %{a: ""}} = make(module, %{a: ""})
    assert {:error, %{a: :missing}} == make(module, %{a: "empty_val"})
  end

  test "pass `make_map` to use/2" do
    module = create_construct [make_map: true] do
      field :a
    end

    assert {:ok, %{a: ""}} == make(module, %{a: ""})
  end

  test "include other structure" do
    include1_module = create_construct do
      field :a, :string, default: nil
      field :b
    end

    include2_module = create_construct do
      field :c, :integer, custom_option: 42
      field :d
    end

    include1 = name(include1_module)
    include2 = name(include2_module)

    module = create_construct do
      include include1
      include include2
    end

    module_name = name(module)

    assert %{a: {:string, [default: nil]}, b: {:string, []}, c: {:integer, [custom_option: 42]}, d: {:string, []}}
        == module_name.__construct__(:types)
  end

  test "make nested fields" do
    module = create_construct do
      field :parent do
        field :nested_struct do
          field :SOME_OF_1 do
            field :c
          end
        end
      end
    end

    assert {:ok, root = %{parent: parent = %{nested_struct: nested = %{SOME_OF_1: some = %{c: "test"}}}}}
         = make(module, %{parent: %{nested_struct: %{SOME_OF_1: %{c: "test"}}}})

    assert Construct.Integration.BuildTest_67 == root.__struct__
    assert Construct.Integration.BuildTest_67.Parent == parent.__struct__
    assert Construct.Integration.BuildTest_67.Parent.NestedStruct == nested.__struct__
    assert Construct.Integration.BuildTest_67.Parent.NestedStruct.SOME_OF1 == some.__struct__
  end

  test "raise when try to use non-atom field name" do
    assert_raise(Construct.DefinitionError, ~s(expected atom for field name, got `"key"`), fn ->
      create_construct do
        field "key", :string
      end
    end)
  end

  test "raise when try to use non-atom field name for nested" do
    assert_raise(Construct.DefinitionError, ~s(expected atom for field name, got `"key"`), fn ->
      create_construct do
        field "key" do
          field "asd"
        end
      end
    end)
  end

  test "raise when trying to use function as default argument" do
    assert_raise(Construct.DefinitionError, ~s(default value cannot to be a function), fn ->
      defmodule M do
        use Construct

        structure do
          field :err, :integer, default: fn -> 42 end
        end
      end
    end)
  end

  test "raise when trying to use undefined module as custom type" do
    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        field :key, UndefinedModule
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        field :key, {:array, UndefinedModule}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        field :key, {:map, UndefinedModule}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined complex type :any), fn ->
      create_construct do
        field :key, {:any, UndefinedModule}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        field :key, [UndefinedModule]
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        field :key, [CustomType, UndefinedModule]
      end
    end)
  end

  test "raise when trying to use custom type that doesn't have cast/1 function" do
    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for Elixir.CustomTypeEmpty), fn ->
      create_construct do
        field :key, CustomTypeEmpty
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for Elixir.CustomTypeEmpty), fn ->
      create_construct do
        field :key, {:array, CustomTypeEmpty}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for Elixir.CustomTypeEmpty), fn ->
      create_construct do
        field :key, {:map, CustomTypeEmpty}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined complex type :any), fn ->
      create_construct do
        field :key, {:any, CustomTypeEmpty}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for Elixir.CustomTypeEmpty), fn ->
      create_construct do
        field :key, [CustomTypeEmpty]
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for Elixir.CustomTypeEmpty), fn ->
      create_construct do
        field :key, [CustomType, CustomTypeEmpty]
      end
    end)
  end

  test "raise when trying to include undefined module" do
    assert_raise(Construct.DefinitionError, ~s(undefined module Elixir.UndefinedModule), fn ->
      create_construct do
        include UndefinedModule
      end
    end)
  end

  test "raise when trying to include invalid structure (some module)" do
    assert_raise(Construct.DefinitionError, ~s(provided Elixir.CustomTypeEmpty is not Construct module), fn ->
      create_construct do
        include CustomTypeEmpty
      end
    end)
  end
end
