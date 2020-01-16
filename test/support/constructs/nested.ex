defmodule Nested do
  defmodule Type do
    def cast(v) when is_binary(v), do: {:ok, v}
    def cast(_), do: {:error, :custom_reason}
  end

  defmodule Embedded do
    use Construct do
      field :e, {:array, Type}
    end
  end

  use Construct do
    field :a
    field :b, :float
    field :c, {:map, :integer}
    field :d, Embedded
  end
end
