### --- Self-dependent module --- ###
defmodule Person do
  use Construct

  structure do
    field :id, :integer
    field :name, :string
    field :friend, Person, default: nil
  end
end
