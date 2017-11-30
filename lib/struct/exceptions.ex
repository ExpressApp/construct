defmodule Struct.Error do
  defexception [:message]
end

defmodule Struct.CastError do
  defexception [:message]
end

defmodule Struct.MakeError do
  defexception [:message]

  def exception(%{reason: reason, params: params}) when is_map(reason) do
    %__MODULE__{message: inspect(traverse_errors(reason, params))}
  end
  def exception(reason) do
    %__MODULE__{message: inspect(reason)}
  end

  defp traverse_errors(reason, params) do
    Enum.reduce(reason, %{}, fn
      ({field, error}, acc) when is_map(error) ->
        Map.put(acc, field, traverse_errors(error, get_params_field(params, field) || %{}))
      ({field, error}, acc) ->
        Map.put(acc, field, {error, get_params_field(params, field)})
    end)
  end

  defp get_params_field(list, field) when is_list(list) do
    Enum.map(list, &(get_params_field(&1, field)))
  end
  defp get_params_field(params, field) when is_map(params) do
    Map.get(params, field) || Map.get(params, Atom.to_string(field))
  end
end

defmodule Struct.DefinitionError do
  defexception [:message]
end
