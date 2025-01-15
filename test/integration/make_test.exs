defmodule Construct.Integration.MakeTest do
  use Construct.TestCase

  # For some reason it keeps emitting a warning about an unused alias
  # while it's actually used.
  alias Construct.Types.CommaList, warn: false

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

  test "field with type `{:array, CustomType}`" do
    embedded_module = create_construct do
      field :a
      field :b
    end

    embedded = name(embedded_module)

    module = create_construct do
      field :key, {:array, embedded}
    end

    assert {:ok, %{key: [%{a: "a", b: "b"}]}} = make(module, %{key: [%{"a" => "a", "b" => "b"}]})
    assert {:error, %{key: %{b: :missing}}} = make(module, %{key: [%{"a" => "a"}]})
    assert {:error, %{key: %{a: :missing, b: :missing}}} = make(module, %{key: ["test1", "test2"]})
  end

  test "field with type `{:map, t}`" do
    module = create_construct do
      field :key, {:map, :string}
    end

    assert {:ok, %{key: %{k1: "v1", k2: "v2"}}} = make(module, %{key: %{k1: "v1", k2: "v2"}})
    assert {:ok, %{key: %{"k1" => "v1", "k2" => "v2"}}} = make(module, %{key: %{"k1" => "v1", "k2" => "v2"}})
  end

  test "field with type `{t, ...}`" do
    module = create_construct do
      field :key, {Nilable, :string}
    end

    assert {:ok, %{key: nil}} = make(module, %{key: nil})
    assert {:ok, %{key: "s"}} = make(module, %{key: "s"})
    assert {:error, %{key: :invalid}} = make(module, %{key: 123})
    assert {:error, %{key: :missing}} = make(module, %{})
  end

  test "field with type `{t, [...]}`" do
    module = create_construct do
      field :key, {Nilable, [CommaList, {:array, :string}]}
    end

    assert {:ok, %{key: nil}} = make(module, %{key: nil})
    assert {:ok, %{key: ["s1", "s2", "s3"]}} = make(module, %{key: "s1,s2,s3"})
    assert {:error, %{key: :invalid}} = make(module, %{key: 123})
    assert {:error, %{key: :missing}} = make(module, %{})
  end

  test "field with type `[t, {t, ...}]`" do
    module = create_construct do
      field :key, [:string, {Construct.Types.Enum, ~w(A B C)}]
    end

    assert {:ok, %{key: "A"}} = make(module, %{key: "A"})
    assert {:error, %{key: [passed_value: "D", valid_values: ["A", "B", "C"]]}} = make(module, %{key: "D"})
    assert {:error, %{key: :invalid}} = make(module, %{key: 123})
    assert {:error, %{key: :missing}} = make(module, %{})
  end

  test "field with type `[t, {:array, {t, ...}}]`" do
    module = create_construct do
      field :key, [CommaList, {:array, {Construct.Types.Enum, ~w(A B C)}}]
    end

    assert {:ok, %{key: ["A"]}} = make(module, %{key: "A"})
    assert {:ok, %{key: ["A", "C", "B"]}} = make(module, %{key: "A,C,B"})
    assert {:error, %{key: [passed_value: "D", valid_values: ["A", "B", "C"]]}} = make(module, %{key: "A,D"})
    assert {:error, %{key: :invalid}} = make(module, %{key: 123})
    assert {:error, %{key: :missing}} = make(module, %{})
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

  test "field with function as default value" do
    module = create_construct do
      field :a, :utc_datetime, default: &NaiveDateTime.utc_now/0
    end

    assert {:ok, struct1} = make(module, %{})
    assert {:ok, struct2} = make(module, %{})
    refute struct1 == struct2
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

  test "make with `error_values` option" do
    opts = [error_values: true]

    module1 = create_construct do
      field :key, :string
    end

    assert {:error, %{key: %{error: :missing, value: nil}}} = make(module1, %{}, opts)
    assert {:error, %{key: %{error: :invalid, value: nil}}} = make(module1, %{key: nil}, opts)
    assert {:error, %{key: %{error: :invalid, value: 1.4}}} = make(module1, %{key: 1.4}, opts)
  end

  test "make with `error_values` option and `{:array, primitive}` type" do
    opts = [error_values: true]

    module = create_construct do
      field :nested, {:array, :string}
    end

    assert {:error, %{nested: %{error: :missing, value: nil, expect: "array of :string is expected"}}}
        == make(module, %{}, opts)

    assert {:error,
             %{
               nested: [
                 %{error: :error, index: 1, value: %{key: "valid"}},
                 %{error: :error, index: 3, value: 42}
               ]
             }}
        == make(module, %{nested: ["string", %{key: "valid"}, "string", 42, "string"]}, opts)

    assert {:error,
             %{
               nested: [
                 %{error: :error, index: 0, value: %{key: "valid"}},
                 %{error: :error, index: 1, value: %{key: :some}},
                 %{error: :error, index: 2, value: %{key: 42}},
                 %{error: :error, index: 3, value: %{key: "valid"}}
               ]
             }}
        == make(module, %{nested: [%{key: "valid"}, %{key: :some}, %{key: 42}, %{key: "valid"}]}, opts)
  end

  test "make with `error_values` option and `{:array, t}` type" do
    opts = [error_values: true]

    module1 = create_construct do
      field :key, CustomType
    end

    module1_type = name(module1)

    module2 = create_construct do
      field :nested, {:array, module1_type}
    end

    assert {:error,
             %{nested: %{error: :missing, value: nil, expect: "array of Construct.Integration.MakeTest_291 is expected"}}}
        == make(module2, %{}, opts)

    assert {:error,
             %{
               nested: [
                 %{
                   error: %{key: %{error: :invalid_custom_list, value: "valid", expect: "CustomType is expected"}},
                   index: 0
                 },
                 %{
                   error: %{key: %{error: :invalid_custom_list, value: :some, expect: "CustomType is expected"}},
                   index: 1
                 }
               ]
             }}
        == make(module2, %{nested: [%{key: "valid"}, %{key: :some}]}, opts)

    assert {:error,
             %{
               nested: [
                 %{
                   error: %{key: %{error: :invalid_custom_list, value: :some, expect: "CustomType is expected"}},
                   index: 1
                 },
                 %{
                   error: %{key: %{error: :invalid_custom_list, value: 42, expect: "CustomType is expected"}},
                   index: 2
                 }
               ]
             }}
        == make(module2, %{nested: [%{key: []}, %{key: :some}, %{key: 42}, %{key: ["valid"]}]}, opts)
  end

  test "make with `error_values` option and nested struct" do
    opts = [error_values: true]

    module1 = create_construct do
      field :key, :string
    end

    module1_type = name(module1)

    module2 = create_construct do
      field :nested, module1_type
    end

    assert {:error, %{nested: %{error: :missing, value: nil}}} = make(module2, %{}, opts)
    assert {:error, %{nested: %{key: %{error: :missing, value: nil}}}} = make(module2, %{nested: %{}}, opts)
  end

  test "make with `error_values` option and docs in custom types" do
    opts = [error_values: true]

    module1 = create_construct do
      @moduledoc "awesome type"
      field :key, Comment
    end

    module1_type = name(module1)

    module2 = create_construct do
      field :nested, {:array, module1_type}
    end

    assert {:error, %{nested: %{error: :missing, value: nil, expect: "array of Construct.Integration.MakeTest_356 is expected"}}}
        == make(module2, %{}, opts)

    assert {:error, %{nested: [%{error: %{key: %{error: :missing, expect: "Comment is expected", value: nil}}, index: 0}]}}
        == make(module2, %{nested: [1]}, opts)
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
      field :b, :string
      field :c, :string, default: "from module"
    end

    assert {:ok, %{a: 0, b: "b", c: "from module"}} = make(module, %{b: "b"})
  end

  test "structure with `include` and only option" do
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
      include include1, only: [:a]
      include include2, only: []
      include include2, only: [:d]
    end

    assert {:ok, %{a: "a", d: "d"}} = make(module, %{a: "a", b: "b", c: "c", d: "d"})
  end

  test "structure with `include` where field in only option doesn't exist" do
    include_module = create_construct do
      field :a
      field :b
    end

    include = name(include_module)

    assert_raise(Construct.DefinitionError, "field :c in :only option doesn't exist in #{inspect(include)}", fn ->
      create_construct do
        include include, only: [:c]
      end
    end)
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
