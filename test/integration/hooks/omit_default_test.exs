defmodule Construct.Integration.Hooks.OmitDefaultTest do
  use Construct.TestCase

  test "omit default values" do
    module = create_module do
      use Construct
      use Construct.Hooks.OmitDefault

      structure do
        field :a

        field :b, [omit_default: true] do
          field :ba, :string, default: "!"
        end

        field :d do
          field :da, :string, default: nil, omit_default: true
        end

        field :c, [omit_default: true] do
          field :ca, :string, default: nil
          field :cb, :string, default: nil, omit_default: true
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
