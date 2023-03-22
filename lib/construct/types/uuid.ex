defmodule Construct.Types.UUID do
  @moduledoc """
  Checks that provided binary is UUID-like string:

      defmodule Structure do
        use Construct do
          field :value, Construct.Types.UUID
        end
      end

      iex> Structure.make!(value: "fd4ddf80-a7d9-4af8-b46c-26fc4566d92c")
      %Structure{value: "fd4ddf80-a7d9-4af8-b46c-26fc4566d92c"}

      iex> Structure.make(value: "invalid")
      {:error, %{value: :invalid}}
  """

  @behaviour Construct.Type

  @impl true
  def cast(<<_::64, ?-, _::32, ?-, _::32, ?-, _::32, ?-, _::96>> = v), do: {:ok, v}
  def cast(_), do: :error
end
