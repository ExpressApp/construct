defmodule Derive do
  @derive {Jason.Encoder, only: [:a, :b, :d]}

  use Construct do
    field :a

    field :b, derive: [{Jason.Encoder, only: [:ba]}] do
      field :ba, derive: Jason.Encoder do
        field :baa, :string, default: "test"
      end

      field :bb, :integer, default: 42
    end

    field :c, :string, default: "not serialized"

    field :d, derive: Jason.Encoder do
      field :da do
        field :daa, :integer, default: 0
      end
    end
  end
end
