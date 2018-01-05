defmodule Roadmap.CycleDepsTest do
  use ExUnit.Case

  test "Casting self-dependent module properly" do
    assert {
      :ok,
      %Person{
        friend: %Person{
          friend: %Person{
            friend: nil,
            id: 3,
            name: "Charlie"
          },
          id: 2,
          name: "Bob"
        },
        id: 1,
        name: "Alice"
      }
    } = Person.make(
      %{
        id: 1,
        name: "Alice",
        friend: %{
          id: 2,
          name: "Bob",
          friend: %{
            id: 3,
            name: "Charlie"
          }
        }
      }
    )
  end

  test "Casting cross-dependent modules properly" do
    assert {
      :ok,
      %Post{
        comments: [
          %Comment{id: 2, post: nil},
          %Comment{id: 3, post: %Post{comments: nil, id: 1}}
        ],
        id: 1
      }
    } = Post.make(
      %{
        id: 1,
        comments: [
          %{id: 2},
          %{id: 3, post: %{id: 1}}
        ]
      }
    )
  end
end
