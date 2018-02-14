defmodule Construct.CastTest do
  use ExUnit.Case

  alias Construct.Cast

  doctest Construct.Cast, import: true

  defmodule Valid do
    use Construct

    structure do
      field :a
    end
  end

  defmodule Invalid do
  end

  defmodule InvalidStructure do
    defstruct [:a]
  end

  describe "#make(module, params, opts)" do
    test "returns structure" do
      assert {:ok, %Construct.CastTest.Valid{a: "test"}} == Cast.make(Valid, %{a: "test"})
    end

    test "returns map with `make_map: true`" do
      assert {:ok, %{a: "test"}} == Cast.make(Valid, %{a: "test"}, make_map: true)
    end

    test "throws error with invalid module" do
      assert_raise(Construct.Error, ~s(undefined structure Construct.CastTest.Invalid, it is not defined or does not exist), fn ->
        Cast.make(Invalid, %{})
      end)
    end

    test "throws error with invalid structure" do
      assert_raise(Construct.Error, ~s(invalid structure Construct.CastTest.InvalidStructure), fn ->
        Cast.make(InvalidStructure, %{})
      end)
    end

    test "throws error with invalid param as structure module" do
      assert_raise(Construct.Error, ~s(undefined structure "some"), fn ->
        Cast.make("some", %{})
      end)
    end
  end

  describe "#make(types, params, opts)" do
    test "returns map" do
      assert {:ok, %{foo: 1}} == Cast.make(%{foo: {:integer, []}}, %{"foo" => "1"})
    end

    test "with type only" do
      assert {:ok, %{foo: 1}} == Cast.make(%{foo: :integer}, %{"foo" => "1"})
      assert {:ok, %{foo: [1, 2]}} == Cast.make(%{foo: {:array, :integer}}, %{"foo" => ["1", "2"]})
      assert {:ok, %{foo: [1, 2, 3]}} == Cast.make(%{foo: [CommaList, {:array, :integer}]}, %{"foo" => "1,2,3"})
    end

    test "with `default: nil`" do
      types = %{foo: {:integer, [default: nil]}}

      assert {:ok, %{foo: nil}} == Cast.make(types, %{})
      assert {:ok, %{foo: 1}} == Cast.make(types, %{"foo" => "1"})
      assert {:ok, %{foo: 1}} == Cast.make(types, %{"foo" => 1})
      assert {:ok, %{foo: nil}} == Cast.make(types, %{"foo" => nil})
    end
  end
end
