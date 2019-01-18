defmodule Construct.Integration.DeriveTest do
  use ExUnit.Case

  test "derive inheritance and override" do
    assert {:ok, structure} = Derive.make(a: "string")

    assert ~s({"a":"string","b":{"ba":{"baa":"test"}},"d":{"da":{"daa":0}}})
        == Jason.encode!(structure)
  end
end
