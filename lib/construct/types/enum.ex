defmodule Construct.Types.Enum do
  @moduledoc """
  Implements an abstract enum type.

  ## Usage

      defmodule MyApp.Order do
        use Construct do
          field :type, {Construct.Types.Enum, [:delivery, :pickup]}
        end
      end

  Then you can validate that `:type` field accepts only specified
  values.

      iex> MyApp.Order.make(%{type: :delivery})
      {:ok, %MyApp.Order{type: :delivery}}
      iex> MyApp.Order.make(%{type: :other})
      {:error, %{type: passed_value: :other, valid_values: [:delivery, :pickup]}}
  """

  @behaviour Construct.TypeC

  @impl true
  def castc(value, variants) when is_list(variants) do
    if value in variants do
      {:ok, value}
    else
      {:error, passed_value: value, valid_values: variants}
    end
  end
end
