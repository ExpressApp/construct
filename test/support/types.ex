defmodule CustomType do
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: {:error, :invalid_custom_list}
end

defmodule EctoType do
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: :error
end

defmodule CustomTypeInvalid do
  def cast(_), do: :invalid_ret
end

defmodule CustomTypeEmpty do
end

defmodule Nilable do
  @behaviour Construct.TypeC

  def castc(nil, _), do: {:ok, nil}
  def castc(val, type), do: Construct.Type.cast(type, val)
end
