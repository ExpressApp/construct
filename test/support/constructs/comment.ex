### --- Cross-dependent modules --- ###
defmodule Comment do
  @moduledoc """
  User's Comment
  """

  use Construct

  structure do
    field :id, :integer
    field :post, Post, default: nil
  end
end
