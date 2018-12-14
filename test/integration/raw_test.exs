defmodule Construct.Integration.RawTest do
  use Construct.TestCase

  defmodule Test1 do
    use Construct, %{a: :integer}
  end

  defmodule Test2 do
    use Construct, %{a: {:integer, []}, b: {%{c: {:integer, []}}, []}}
  end

  defmodule Test3 do
    use Construct, %{a: :integer, b: %{c: :integer}}
  end

  defmodule Test4 do
    use Construct, %{a: {:integer, default: 0}, b: %{c: {:integer, default: 42}}}
  end

  test "defines structure from raw types" do
    assert {:ok, %Test1{a: 42}}
        == Test1.make(a: 42)

    assert {:ok, %Test2{a: 42, b: %Test2.B{c: 1}}}
        == Test2.make(a: 42, b: [c: 1])

    assert {:ok, %Test3{a: 42, b: %Test3.B{c: 1}}}
        == Test3.make(a: 42, b: [c: 1])

    assert {:ok, %Test4{a: 0, b: %Test4.B{c: 42}}}
        == Test4.make
  end
end
