### --- Cross-dependent modules --- ###
defmodule Comment do
  use Construct

  structure do
    field :id, :integer
    field :post, Post, default: nil
  end
end
