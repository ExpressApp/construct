defmodule Construct.Integration.StructTest do
  use Construct.TestCase

  defmodule Test0 do
    use Construct

    structure do
      field :a do
        field :b do
          field :c, :string, default: "test"
          field :d, :string, default: "test"
        end
      end

      field :e, :string, default: "test"
    end
  end

  defmodule Test1 do
    use Construct

    structure do
      field :a do
        field :b do
          field :c, :string
          field :d, :string, default: "test"
        end
      end

      field :e
    end
  end

  defmodule Test2 do
    use Construct

    structure do
      field :test, Test2
    end
  end

  defmodule Test30 do
    use Construct

    structure do
      field :a, :string
    end
  end

  defmodule Test31 do
    use Construct

    structure do
      include Test30

      field :a, :string, default: "test"
    end
  end

  test "struct should be equal with make" do
    assert struct!(Test0) == Test0.make!()
  end

  test "struct have nested structs with all defaults" do
    assert %Test0{a: %Test0.A{b: %Test0.A.B{c: "test", d: "test"}}, e: "test"}
        == struct!(Test0)
  end

  test "struct default overwriting should reset enforce_keys" do
    assert %Test31{}
  end

  test "struct have nested structs without defaults in some fields" do
    assert_raise(ArgumentError, enforce_keys_message(Test1, [:e, :a]), fn ->
      struct!(Test1)
    end)

    assert {:error, %{e: :missing, a: :missing}} == Test1.make()

    assert_raise(ArgumentError, enforce_keys_message(Test1, [:a]), fn ->
      struct!(Test1, %{e: "test"})
    end)

    assert {:error, %{a: :missing}} == Test1.make(%{e: "test"})

    assert_raise(ArgumentError, enforce_keys_message(Test1.A, [:b]), fn ->
      struct!(Test1.A)
    end)

    assert {:error, %{b: :missing}} == Test1.A.make()

    assert_raise(ArgumentError, enforce_keys_message(Test1.A.B, [:c]), fn ->
      struct!(Test1.A.B)
    end)

    assert {:error, %{c: :missing}} == Test1.A.B.make()
  end

  test "cycle deps" do
    assert_raise(ArgumentError, enforce_keys_message(Test2, [:test]), fn ->
      struct!(Test2)
    end)
  end

  defp enforce_keys_message(mod, keys) do
    "the following keys must also be given when building struct #{inspect(mod)}: #{inspect(keys)}"
  end
end
