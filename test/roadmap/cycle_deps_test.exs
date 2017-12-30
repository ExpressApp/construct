defmodule Roadmap.CycleDepsTest do
  use ExUnit.Case

  test "Compile self dependent module" do
    defmodule User do
      use Construct

      structure do
        field :id, :integer
        field :name, :string
        field :friend, Roadmap.CycleDepsTest.User, default: nil
      end
    end

    :code.delete(Roadmap.CycleDepsTest.User)
  end

  test "Compile cross-dependent modules" do
    defmodule Post do
      use Construct

      structure do
        field :id, :integer
        field :name, :string
        field :title, :string
        field :comments, {:array, Roadmap.CycleDepsTest.Comment}, default: nil
      end
    end

    defmodule Comment do
      use Construct

      structure do
        field :id, :integer
        field :title, :string
        field :post, Roadmap.CycleDepsTest.Post, default: nil
      end
    end

    :code.delete(Roadmap.CycleDepsTest.Comment)
    :code.delete(Roadmap.CycleDepsTest.Post)
  end
end
