defmodule Construct.Integration.MakeTest do
  use Construct.TestCase

  test "with simple stupid params" do
    module = create_construct do
      field :key
    end

    assert {:ok, %{key: "test"}} = make(module, %{key: "test"})
  end

  test "with params made from self" do
    module = create_construct do
      field :key
    end

    assert {:ok, struct} = make(module, %{key: "test"})
    assert {:ok, %{key: "test"}} = make(module, struct)
  end

  test "with params as keyword list" do
    module = create_construct do
      field :key
    end

    assert {:ok, %{key: "test"}} = make(module, key: "test")
  end

  test "field with type `{:array, t}`" do
    module = create_construct do
      field :key, {:array, :string}
    end

    assert {:ok, %{key: ["test1", "test2"]}} = make(module, %{key: ["test1", "test2"]})
  end

  test "field with type `{:map, t}`" do
    module = create_construct do
      field :key, {:map, :string}
    end

    assert {:ok, %{key: %{k1: "v1", k2: "v2"}}} = make(module, %{key: %{k1: "v1", k2: "v2"}})
    assert {:ok, %{key: %{"k1" => "v1", "k2" => "v2"}}} = make(module, %{key: %{"k1" => "v1", "k2" => "v2"}})
  end

  test "field with type `:struct`" do
    nested_module = create_construct do
      field :key
    end

    module = create_construct do
      field :key, :struct
    end

    assert {:ok, nested} = make(nested_module, %{key: "test"})
    assert {:ok, %{key: %{key: "test"} = value}} = make(module, %{key: nested})
    assert Map.has_key?(value, :__struct__)
  end

  test "field with type `any`" do
    module = create_construct do
      field :key, :any
    end

    assert {:ok, %{key: :any}} = make(module, %{key: :any})
    assert {:ok, %{key: "qw"}} = make(module, %{key: "qw"})
    assert {:ok, %{key: 1234}} = make(module, %{key: 1234})
  end

  test "field with embedded structure" do
    embedded_module = create_construct do
      field :a, :integer
      field :b, {:array, :float}
    end

    embedded = name(embedded_module)

    module = create_construct do
      field :emb, embedded
    end

    assert {:error, %{emb: :missing}} = make(module, %{})
    assert {:error, %{emb: %{a: :missing, b: :missing}}} = make(module, %{emb: %{}})
    assert {:error, %{emb: %{a: :missing}}} = make(module, %{emb: %{b: ["1.2", 1.42]}})
    assert {:error, %{emb: %{a: :invalid, b: :missing}}} = make(module, %{emb: %{a: "qwe"}})
    assert {:ok, %{emb: %{a: 1, b: [1.2, 1.42]}}} = make(module, %{emb: %{a: "1", b: ["1.2", 1.42]}})
  end

  test "field without default value" do
    module = create_construct do
      field :key, :string
    end

    assert {:error, %{key: :missing}} = make(module, %{})
    assert {:error, %{key: :invalid}} = make(module, %{key: nil})
    assert {:ok, %{key: "test"}} = make(module, %{key: "test"})
  end

  test "field with default value `nil`" do
    module = create_construct do
      field :key, :string, default: nil
    end

    assert {:ok, %{key: nil}} = make(module, %{})
    assert {:ok, %{key: nil}} = make(module, %{key: nil})
    assert {:ok, %{key: "test"}} = make(module, %{key: "test"})
  end

  test "field with default value `%{}`" do
    module = create_construct do
      field :key, :map, default: %{}
    end

    assert {:ok, %{key: %{}}} = make(module, %{})
    assert {:error, %{key: :invalid}} = make(module, %{key: nil})
    assert {:ok, %{key: %{}}} = make(module, %{key: %{}})
  end

  test "field with custom type (Construct.Type, when error may have reason)" do
    module = create_construct do
      field :key, CustomType
    end

    assert {:error, %{key: :missing}} = make(module, %{})
    assert {:error, %{key: :invalid_custom_list}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
  end

  test "field with custom type (Ecto.Type)" do
    module = create_construct do
      field :key, EctoType
    end

    assert {:error, %{key: :missing}} = make(module, %{})
    assert {:error, %{key: :invalid}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
  end

  test "field with custom type and default value `nil`" do
    module = create_construct do
      field :key, CustomType, default: nil
    end

    assert {:ok, %{key: nil}} = make(module, %{})
    assert {:ok, %{key: nil}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
  end

  test "field with custom type and default value `[]`" do
    module = create_construct do
      field :key, CustomType, default: []
    end

    assert {:ok, %{key: []}} = make(module, %{})
    assert {:error, %{key: :invalid_custom_list}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
  end

  test "field with in place nested structure" do
    module = create_construct do
      field :a do
        field :b
      end
    end

    assert {:ok, %{a: %{b: "test"}}} = make(module, %{a: %{b: "test"}})
  end

  test "make with `empty_values` option" do
    opts = [empty_values: [nil, "", "test", 1.42]]

    module = create_construct do
      field :key, :string
    end

    assert {:error, %{key: :missing}} = make(module, %{key: nil}, opts)
    assert {:error, %{key: :missing}} = make(module, %{key: ""}, opts)
    assert {:error, %{key: :missing}} = make(module, %{key: "test"}, opts)
    assert {:error, %{key: :missing}} = make(module, %{key: 1.42}, opts)
    assert {:ok, %{key: "qwe"}} = make(module, %{key: "qwe"}, opts)
  end

  test "make with `make_map: false` option" do
    module = create_construct do
      field :key
    end

    assert {:ok, structure} = make(module, %{key: "test"}, make_map: false)
    assert Map.has_key?(structure, :__struct__)
  end

  test "make with `make_map: true` option" do
    module = create_construct do
      field :key
    end

    assert {:ok, structure} = make(module, %{key: "test"}, make_map: true)
    refute Map.has_key?(structure, :__struct__)
  end

  test "structure with `include`" do
    include1_module = create_construct do
      field :a
      field :b
    end

    include2_module = create_construct do
      field :c
      field :d
    end

    include1 = name(include1_module)
    include2 = name(include2_module)

    module = create_construct do
      include include1
      include include2
    end

    assert {:ok, %{a: "a", b: "b", c: "c", d: "d"}} = make(module, %{a: "a", b: "b", c: "c", d: "d"})
  end

  test "structure with fields that overrides previously defined in include" do
    include1_module = create_construct do
      field :a, :string
      field :b, :string
      field :c, :string, default: "from include"
    end

    include1 = name(include1_module)

    module = create_construct do
      include include1

      field :a, :integer, default: 0
      field :c, :string, default: "from module"
    end

    assert {:ok, %{a: 0, b: "b", c: "from module"}} = make(module, %{b: "b"})
  end

  test "field with `[CommaList, {:array, :integer}]` type" do
    module = create_construct do
      field :key, [CommaList, {:array, :integer}]
    end

    assert {:error, %{key: :missing}} = make(module, %{})
    assert {:error, %{key: :invalid}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
    assert {:ok, %{key: []}} = make(module, %{key: ""})
    assert {:error, %{key: :invalid}} = make(module, %{key: "1,b,3"})
    assert {:ok, %{key: [1, 2, 3]}} = make(module, %{key: "1,2,3"})
    assert {:ok, %{key: [1, 2, 3]}} = make(module, %{key: ["1", "2", "3"]})
    assert {:ok, %{key: [1, 2, 3]}} = make(module, %{key: [1, 2, 3]})
  end

  test "field with `[CommaList, {:array, :integer}]` type and default `nil`" do
    module = create_construct do
      field :key, [CommaList, {:array, :integer}], default: nil
    end

    assert {:ok, %{key: nil}} = make(module, %{})
    assert {:ok, %{key: nil}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
    assert {:ok, %{key: []}} = make(module, %{key: ""})
  end

  test "field with `[CommaList, {:array, :integer}]` type and default `[]`" do
    module = create_construct do
      field :key, [CommaList, {:array, :integer}], default: []
    end

    assert {:ok, %{key: []}} = make(module, %{})
    assert {:error, %{key: :invalid}} = make(module, %{key: nil})
    assert {:ok, %{key: []}} = make(module, %{key: []})
    assert {:ok, %{key: []}} = make(module, %{key: ""})
  end

  test "raise when try to provide mixed key types as params" do
    module = create_construct do
      field :a
      field :b
    end

    message = "expected params to be a map or keyword list with atom or string keys, " <>
              "got a map with mixed keys: %{:b => \"10\", \"a\" => \"john\"}"

    assert_raise(Construct.MakeError, message, fn ->
      make(module, %{"a" => "john", b: "10"})
    end)
  end

  test "raise when custom type returns unacceptable" do
    module = create_construct do
      field :key, CustomTypeInvalid
    end

    message = "expected CustomTypeInvalid to return {:ok, term} | {:error, term} | :error, " <>
              "got an unexpected value: `:invalid_ret`"

    assert_raise(Construct.MakeError, message, fn ->
      make(module, %{key: "test"})
    end)
  end

  test "using make!" do
    module = create_construct do
      field :a
      field :b do
        field :c, :integer
        field :d, {:array, :integer}, default: []
        field :e, CustomType, default: nil
      end
    end

    assert %{a: "a", b: %{c: 1}} = make!(module, %{a: "a", b: %{c: "1"}})

    assert_raise(Construct.MakeError, ~s(%{a: {:missing, nil}, b: {:missing, nil}}), fn ->
      make!(module, %{})
    end)

    assert_raise(Construct.MakeError, ~s(%{b: {:missing, nil}}), fn ->
      make!(module, %{a: "a"})
    end)

    assert_raise(Construct.MakeError, ~s(%{b: {:missing, nil}}), fn ->
      make!(module, [a: "a"])
    end)

    assert_raise(Construct.MakeError, ~s(%{b: %{c: {:missing, nil}}}), fn ->
      make!(module, %{a: "a", b: %{}})
    end)

    assert_raise(Construct.MakeError, ~s(%{b: %{c: {:invalid, \"a\"}}}), fn ->
      make!(module, %{a: "a", b: %{c: "a"}})
    end)

    assert_raise(Construct.MakeError, ~s(%{b: %{d: {:invalid, [\"a\", \"1\", :test]}}}), fn ->
      make!(module, %{a: "a", b: %{c: "1", d: ["a", "1", :test]}})
    end)

    assert_raise(Construct.MakeError, ~s(%{b: %{e: {:invalid_custom_list, \"test\"}}}), fn ->
      make!(module, %{a: "a", b: %{c: "1", e: "test"}})
    end)
  end
end
