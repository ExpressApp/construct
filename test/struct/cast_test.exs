defmodule Struct.CastTest do
  use ExUnit.Case

  alias Struct.Cast

  defmodule Valid do
    use Struct

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
      assert {:ok, %Struct.CastTest.Valid{a: "test"}} == Cast.make(Valid, %{a: "test"})
    end

    test "returns map with `make_map: true`" do
      assert {:ok, %{a: "test"}} == Cast.make(Valid, %{a: "test"}, make_map: true)
    end

    test "throws error with invalid module" do
      assert_raise(Struct.Error, ~s(invalid struct Struct.CastTest.Invalid), fn ->
        Cast.make(Invalid, %{})
      end)
    end

    test "throws error with invalid structure" do
      assert_raise(Struct.Error, ~s(invalid struct Struct.CastTest.InvalidStructure), fn ->
        Cast.make(InvalidStructure, %{})
      end)
    end

    test "throws error with invalid param as struct module" do
      assert_raise(Struct.Error, ~s(undefined struct "some"), fn ->
        Cast.make("some", %{})
      end)
    end
  end

  describe "#make(types, params, opts)" do
    test "returns map" do
      assert {:ok, %{foo: 1}} == Cast.make(%{foo: {:integer, []}}, %{"foo" => "1"})
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
