defmodule Construct.Integration.CycleDepsTest do
  use ExUnit.Case

  test "makes self-dependent constructs properly" do
    assert {:ok, %Person{id: 1, name: "Alice",
                         friend: %Person{id: 2, name: "Bob",
                                         friend: %Person{id: 3, name: "Charlie", friend: nil}}}}
        == Person.make(%{id: 1, name: "Alice",
                         friend: %{id: 2, name: "Bob",
                                   friend: %{id: 3, name: "Charlie"}}})
  end

  test "makes cross-dependent constructs properly" do
    assert {:ok, %Post{id: 1, comments: [%Comment{id: 2, post: nil},
                                         %Comment{id: 3, post: %Post{comments: nil, id: 1}}]}}
        == Post.make(%{id: 1, comments: [%{id: 2}, %{id: 3, post: %{id: 1}}]})
  end
end
