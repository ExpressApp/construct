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

  describe "makes structure when" do
    test "pass valid module" do
      assert {:ok, %Struct.CastTest.Valid{a: "test"}}
          == Cast.make(Valid, %{a: "test"})
    end
  end

  describe "makes map with make_map option when" do
    test "pass valid module" do
      assert {:ok, %{a: "test"}}
        == Cast.make(Valid, %{a: "test"}, make_map: true)
    end
  end

  describe "throws error when" do
    test "pass invalid module" do
      assert_raise(Struct.Error, fn ->
        Cast.make(Invalid, %{})
      end)
    end

    test "pass invalid structure" do
      assert_raise(Struct.Error, fn ->
        Cast.make(InvalidStructure, %{})
      end)
    end

    test "pass invalid value as module" do
      assert_raise(Struct.Error, fn ->
        Cast.make("some", %{})
      end)
    end
  end
end
