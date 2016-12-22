defmodule Struct.Error do
  defexception [:message]
end

defmodule Struct.CastError do
  defexception [:message]
end

defmodule Struct.MakeError do
  defexception [:message]

  def exception(errors) do
    %__MODULE__{message: inspect(errors)}
  end
end

defmodule Struct.DefinitionError do
  defexception [:message]
end
