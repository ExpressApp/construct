### --- Cross-dependent modules --- ###
defmodule Post do
  use Construct

  structure do
    field :id, :integer
    field :comments, {:array, Comment}, default: nil
  end
end
