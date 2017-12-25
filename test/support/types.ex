defmodule CustomType do
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: {:error, :invalid_custom_list}
end

defmodule EctoType do
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: :error
end

defmodule CommaList do
  def cast(""), do: {:ok, []}
  def cast(v) when is_binary(v), do: {:ok, String.split(v, ",")}
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: :error
end

defmodule CustomTypeInvalid do
  def cast(_), do: :invalid_ret
end

defmodule CustomTypeEmpty do
end
