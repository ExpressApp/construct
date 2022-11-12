defmodule Construct.Integration.Hooks.OmitDefaultTest do
  use Construct.TestCase

  test "omit default values" do
    module = create_module do
      use Construct
      use Construct.Hooks.OmitDefault

      structure do
        field :a

        field :b do
          field :ba, :string, default: "!"
        end

        field :d, [omit_default: false] do
          field :da, :string, default: nil
        end

        field :c do
          field :ca, :string, default: nil, omit_default: false
          field :cb, :string, default: nil
        end
      end
    end

    assert {:ok, %{
      a: "test",
      d: %{}
    }} == make(module, %{a: "test"})

    assert {:ok, %{
      a: "test",
      d: %{}
    }} == make(module, %{a: "test", b: %{}, d: %{}})

    assert {:ok, %{
      a: "test",
      d: %{da: "test"}
    }} == make(module, %{a: "test", b: %{}, d: %{da: "test"}})

    assert {:ok, %{
      a: "test",
      d: %{}
    }} == make(module, %{a: "test", c: %{}})

    assert {:ok, %{
      a: "test",
      d: %{},
      c: %{ca: "test"}
    }} == make(module, %{a: "test", c: %{ca: "test"}})

    assert {:ok, %{
      a: "test",
      d: %{},
      c: %{ca: nil, cb: "test"}
    }} == make(module, %{a: "test", c: %{cb: "test"}})
  end
end
