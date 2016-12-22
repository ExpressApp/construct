defmodule Struct.Error do
  defexception [:message]
end

defmodule Struct.CastError do
  defexception [:message]
end

defmodule Struct.DefinitionError do
  defexception [:message]
end
