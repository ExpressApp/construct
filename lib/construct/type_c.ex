defmodule Construct.TypeC do
  @moduledoc """
  Provides a way to create parametrized types.

  See `Construct.Types.Enum` implementation for more information.
  """

  @callback castc(term, arg :: term) :: Construct.Type.cast_ret()
end
