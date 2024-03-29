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

    module_name = name(module)

    assert {:ok, root = %{parent: parent = %{nested_struct: nested = %{SOME_OF_1: some = %{c: "test"}}}}}
         = make(module, %{parent: %{nested_struct: %{SOME_OF_1: %{c: "test"}}}})

    assert Module.concat([module_name]) == root.__struct__
    assert Module.concat([module_name, Parent]) == parent.__struct__
    assert Module.concat([module_name, Parent, NestedStruct]) == nested.__struct__
    assert Module.concat([module_name, Parent, NestedStruct, SOME_OF1]) == some.__struct__
  end

  test "able to define our own typespec" do
    create_module do
      @type t :: %__MODULE__{
        module: module() | term()
      }

      use Construct do
        field :module, :any, default: String
      end
    end
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

  test "raise when trying to use function with non-zero arity as default argument" do
    assert_raise(Construct.DefinitionError, ~s(functions in default values should be zero-arity), fn ->
      defmodule M do
        use Construct do
          field :err, :integer, default: fn(_, _) -> 42 end
        end
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(functions in default values should be zero-arity), fn ->
      defmodule N do
        use Construct do
          field :err, :integer, default: fn(_) -> 42 end
        end
      end
    end)
  end

  test "raise when trying to use undefined module as custom type" do
    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, UndefinedModule
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, {:array, UndefinedModule}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, {:map, UndefinedModule}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, {UndefinedModule, []}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, [UndefinedModule]
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined module UndefinedModule), fn ->
      create_construct do
        field :key, [CustomType, UndefinedModule]
      end
    end)
  end

  test "raise when trying to use custom type that doesn't have cast/1 function" do
    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, CustomTypeEmpty
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, {:array, CustomTypeEmpty}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, {:map, CustomTypeEmpty}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function castc/2 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, {CustomTypeEmpty, []}
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, [CustomTypeEmpty]
      end
    end)

    assert_raise(Construct.DefinitionError, ~s(undefined function cast/1 for CustomTypeEmpty), fn ->
      create_construct do
        field :key, [CustomType, CustomTypeEmpty]
      end
    end)
  end

  test "raise when trying to include undefined module" do
    assert_raise(Construct.DefinitionError, ~s(provided UndefinedModule is not Construct module), fn ->
      create_construct do
        include UndefinedModule
      end
    end)
  end

  test "raise when trying to include invalid structure (some module)" do
    assert_raise(Construct.DefinitionError, ~s(provided CustomTypeEmpty is not Construct module), fn ->
      create_construct do
        include CustomTypeEmpty
      end
    end)
  end
end
