defmodule Construct.Cast do
  @moduledoc """
  Module to make structure instance from provided params.

  You can use it standalone, without defining structure, by providing types and params to `make/3`.
  """

  @default_value :__construct_no_default_value__

  @type type :: {Construct.Type.t, Keyword.t}
  @type types :: %{required(atom) => type}
  @type options :: [error_values: boolean]

  @doc """
  Function to compose structure instance from params:

      defmodule User do
        use Construct

        structure do
          field :name
        end
      end

      iex> make(User, %{name: "john doe"})
      {:ok, %User{name: "john doe"}}

      iex> make(User, name: "john doe")
      {:ok, %User{name: "john doe"}}

  Also you can use it as standalone complex type-coercion by providing types and params:

      iex> make(%{name: {:string, []}}, %{"name" => "john doe"})
      {:ok, %{name: "john doe"}}

      iex> make(%{name: :string}, %{"name" => "john doe"})
      {:ok, %{name: "john doe"}}

      iex> make([name: :string], %{"name" => "john doe"})
      {:ok, %{name: "john doe"}}

      iex> make(%{age: {:integer, [default: 18]}}, %{"age" => "42"})
      {:ok, %{age: 42}}

      iex> make(%{age: {:integer, [default: 18]}}, %{})
      {:ok, %{age: 18}}

      iex> types = %{title: {:string, []}, comments: {{:array, :string}, default: []}}
      iex> make(types, %{title: "article", comments: ["awesome", "great!", "whoa!"]})
      {:ok, %{title: "article", comments: ["awesome", "great!", "whoa!"]}}

      iex> make(%{user: %{name: :string, age: {:integer, default: 21}}}, %{"user" => %{"name" => "john"}})
      {:ok, %{user: %{name: "john", age: 21}}}

  """
  @spec make(atom | types, map, options) :: {:ok, Construct.t | map} | {:error, term}
  def make(struct_or_types, params, opts \\ [])

  def make(module, params, opts) when is_atom(module) do
    make_struct(make_struct_instance(module), collect_types(module), params, opts)
  end

  def make(types, params, opts) do
    cast_params(types, params, opts)
  end

  @doc false
  defp collect_types(module) do
    try do
      module.__construct__(:types)
    rescue
      UndefinedFunctionError ->
        raise Construct.Error, "invalid structure #{inspect(module)}"
    end
  end

  @doc false
  defp make_struct_instance(module) do
    try do
      struct(module)
    rescue
      UndefinedFunctionError ->
        raise Construct.Error, "undefined structure #{inspect(module)}, it is not defined or does not exist"
    end
  end

  @doc false
  defp make_struct(%{__struct__: _module} = struct, types, params, opts) do
    case cast_params(types, params, opts) do
      {:ok, changes} ->
        {:ok, struct(struct, changes)}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp cast_params(types, params, opts) do
    params = convert_params(params)
    types = convert_types(types)
    permitted = Map.keys(types)

    case Enum.reduce(permitted, {%{}, %{}, true}, &process_param(&1, params, types, opts, &2)) do
      {changes, _errors, true} -> {:ok, changes}
      {_changes, errors, false} -> {:error, errors}
    end
  end

  defp convert_params(%_{} = params) do
    convert_params(Map.from_struct(params))
  end

  defp convert_params(params) when is_list(params) or is_map(params) do
    Enum.reduce(params, nil, fn
      ({key, _value}, nil) when is_binary(key) ->
        nil

      ({key, _value}, _) when is_binary(key) ->
        raise Construct.MakeError, "expected params to be a map or keyword list with atom or string keys, " <>
                                   "got a map with mixed keys: #{inspect(params)}"

      ({key, value}, nil) when is_atom(key) ->
        [{Atom.to_string(key), value}]

      ({key, value}, acc) when is_atom(key) ->
        [{Atom.to_string(key), value} | acc]

      (invalid_kv, _acc) ->
        raise Construct.MakeError, "expected params to be a {key, value} structure, got: #{inspect(invalid_kv)}"

    end)
    |> case do
         nil -> params
         list -> Enum.into(list, %{})
       end
  end

  defp convert_params(params) do
    params
  end

  defp convert_types(types) when is_map(types) do
    types
  end

  defp convert_types(types) when is_list(types) do
    Enum.into(types, %{})
  end

  defp convert_types(invalid_types) do
    raise Construct.Error, "expected types to be a {key, value} structure, got: #{inspect(invalid_types)}"
  end

  defp process_param(key, params, types, opts, {changes, errors, valid?}) do
    param_key = Atom.to_string(key)
    {type, type_opts} = type!(key, types)

    case cast_field(param_key, type, type_opts, params, opts) do
      {:ok, value} ->
        {Map.put(changes, key, value), errors, valid?}
      {:error, reason} ->
        {changes, Map.put(errors, key, reason), false}
    end
  end

  defp type!(key, types) do
    case types do
      %{^key => {type, []}} -> {type, []}
      %{^key => {type, [{_,_}|_] = type_opts}} -> {type, type_opts}
      %{^key => type} -> {type, []}
      _ -> raise Construct.Error, "unknown field `#{key}`"
    end
  end

  defp cast_field(param_key, type, type_opts, params, opts) do
    default_value = Keyword.get(type_opts, :default, @default_value)
    error_values = Keyword.get(opts, :error_values, false)

    case params do
      %{^param_key => value} when default_value != @default_value and value == default_value ->
        {:ok, value}

      %{^param_key => value} ->
        put_value(type, error_values, value, cast_field_value(type, value, opts))

      _ ->
        if default_value == @default_value do
          put_value(type, error_values, nil, {:error, :missing})
        else
          {:ok, make_default_value(default_value)}
        end

    end
  end

  defp make_default_value(value) when is_function(value, 0) do
    value.()
  end

  defp make_default_value(value) do
    value
  end

  defp cast_field_value(type, value, opts) do
    case Construct.Type.cast(type, value, opts) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        {:error, reason}

      :error ->
        {:error, :invalid}

      any ->
        raise Construct.MakeError,
          "expected #{inspect(type)} to return {:ok, term} | {:error, term} | :error, " <>
          "got an unexpected value: `#{inspect(any)}`"
    end
  end

  defp put_value(_, true, _value, {:error, reason}) when is_map(reason) do
    {:error, reason}
  end

  defp put_value(_, true, _value, {:error, reason}) when is_list(reason) do
    {:error, reason}
  end

  defp put_value(type, true, value, {:error, reason}) do
    {:error, %{error: reason, value: value, expect: fetch_docs(type)}}
  end

  defp put_value(_, _, _, return) do
    return
  end

  defp fetch_docs({box, arg} = type) do
    if Construct.Type.primitive?(type) do
      "#{box} of #{inspect(arg)} is expected"
    else
      fetch_docs(box)
    end
  end

  defp fetch_docs(type) do
    "#{inspect(type)} is expected"
  end
end
