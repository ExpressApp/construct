defmodule Construct.Integration.Hooks.MapTest do
  use Construct.TestCase

  test "makes map from structs" do
    module = create_module do
      use Construct
      use Construct.Hooks.Map

      structure do
        field :a

        field :b do
          field :ba, :string, default: "!"

          field :bb do
            field :bba, :string, default: "?"
          end
        end
      end
    end

    assert {:ok, %{
      a: "test",
      b: %{ba: "!", bb: %{bba: "?"}}
    }} == make(module, %{a: "test"})

    assert {:ok, %{
      a: "test",
      b: %{ba: "!", bb: %{bba: "#"}}
    }} == make(module, %{a: "test", b: %{bb: %{bba: "#"}}})
  end
end
