defmodule Struct.Cast do
  @empty_values []

  def make(module, params, opts \\ [])
  def make(module, params, opts) when is_atom(module) do
    make(make_struct_instance(module), collect_types(module), params, opts)
  end
  def make(struct, _params, _opts) do
    raise Struct.Error, "undefined struct #{inspect struct}"
  end

  @doc false
  defp collect_types(module) do
    try do
      Enum.into(module.__schema__(:types), %{}, fn({k, _v}) ->
        {k, module.__schema__(:type, k)}
      end)
    rescue
      UndefinedFunctionError ->
        raise Struct.Error, "invalid struct #{inspect module}"
    end
  end

  @doc false
  defp make_struct_instance(module) do
    try do
      module.__struct__()
    rescue
      UndefinedFunctionError ->
        raise Struct.Error, "invalid struct #{inspect module}"
    end
  end

  @doc false
  defp make(%{__struct__: _module} = struct, types, params, opts) do
    {empty_values, _opts} = Keyword.pop(opts, :empty_values, @empty_values)
    make_map? = Keyword.get(opts, :make_map, false)
    params = convert_params(params)
    permitted = Map.keys(types)
    data = struct

    {changes, errors, valid?} =
      Enum.reduce(permitted, {%{}, %{}, true},
                  &process_param(&1, params, types, data, empty_values, opts, &2))

    if valid? do
      changes = apply_changes(struct, changes)
      if make_map? do
        {:ok, Map.from_struct(changes)}
      else
        {:ok, changes}
      end
    else
      {:error, errors}
    end
  end

  @doc false
  def convert_params(%{__struct__: _} = params) do
    convert_params(Map.from_struct(params))
  end
  def convert_params(params) do
    Enum.reduce(params, nil, fn
      ({key, _value}, nil) when is_binary(key) ->
        nil

      ({key, _value}, _) when is_binary(key) ->
        raise Struct.CastError, "expected params to be a map with atoms or string keys, " <>
                                "got a map with mixed keys: #{inspect params}"

      ({key, value}, acc) when is_atom(key) ->
        Map.put(acc || %{}, Atom.to_string(key), value)

    end) || params
  end

  defp process_param(key, params, types, data, empty_values, opts, {changes, errors, valid?}) do
    {key, param_key} = cast_key(key)
    {type, type_opts} = type!(types, key)

    required? = Keyword.get(type_opts, :required, true)
    current = Map.get(data, key)

    case cast_field(key, param_key, type, type_opts, params, current, empty_values, opts, valid?) do
      {:ok, value, valid?} ->
        {Map.put(changes, key, value), errors, valid?}
      :missing ->
        if required? do
          {changes, Map.put(errors, key, :missing), false}
        else
          {changes, errors, valid?}
        end
      :same ->
        {changes, errors, valid?}
      {:error, reason} ->
        {changes, Map.put(errors, key, reason), false}
    end
  end

  defp type!(types, key) do
    case Map.fetch(types, key) do
      {:ok, type} ->
        type
      :error ->
        raise Struct.Error, "unknown field `#{key}`"
    end
  end

  defp cast_key(key) when is_binary(key) do
    try do
      {String.to_existing_atom(key), key}
    rescue
      ArgumentError ->
        raise Struct.Error, "could not convert the parameter `#{key}` into an atom, " <>
                            "`#{key}` is not a schema field"
    end
  end
  defp cast_key(key) when is_atom(key) do
    {key, Atom.to_string(key)}
  end

  defp cast_field(_key, param_key, type, type_opts, params, current, empty_values, opts, valid?) do
    case Map.fetch(params, param_key) do
      {:ok, value} ->
        case Struct.Type.cast(type, value, opts) do
          {:ok, ^current} ->
            :same
          {:ok, value} ->
            if value in empty_values do
              :missing
            else
              {:ok, value, valid?}
            end
          {:error, reason} ->
            {:error, reason}
          :error ->
            {:error, :invalid}
        end
      :error ->
        case Keyword.fetch(type_opts, :default) do
          {:ok, value} -> {:ok, value, valid?}
          :error -> :missing
        end
    end
  end

  defp apply_changes(struct, changes) when changes == %{} do
    struct
  end
  defp apply_changes(struct, changes) do
    Kernel.struct(struct, changes)
  end
end
