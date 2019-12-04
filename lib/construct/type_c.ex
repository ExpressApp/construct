defmodule Construct.TypeC do
  @callback castc(term, arg :: term) :: Construct.Type.cast_ret()
end
