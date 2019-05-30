defmodule Construct.Cast do
  @moduledoc """
  Module to make structure instance from provided params.

  You can use it standalone, without defining structure, by providing types and params to `make/3`.
  """

  @default_value :__construct_no_default_value__

  @type type :: {Construct.Type.t, Keyword.t}
  @type types :: %{required(atom) => type}
  @type options :: [make_map: boolean, empty_values: list(term)]

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

  Options:

    * `make_map` — return result as map instead of structure, defaults to false;
    * `empty_values` — list of terms indicates empty values, defaults to [].

  Example of `empty_values`:

      iex> make(%{name: {:string, []}}, %{name: ""}, empty_values: [""])
      {:error, %{name: :missing}}

      iex> make(%{name: {:string, []}}, %{name: "john"}, empty_values: ["john"])
      {:error, %{name: :missing}}
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
    make_map? = Keyword.get(opts, :make_map, false)

    case cast_params(types, params, opts) do
      {:ok, changes} ->
        if make_map? do
          {:ok, changes}
        else
          {:ok, struct(struct, changes)}
        end
      {:error, errors} ->
        {:error, errors}
    end
  end

  defp cast_params(types, params, opts) do
    empty_values = Keyword.get(opts, :empty_values, [])
    params = convert_params(params)
    types = convert_types(types)
    permitted = Map.keys(types)

    case Enum.reduce(permitted, {%{}, %{}, true},
                     &process_param(&1, params, types, empty_values, opts, &2)) do
      {changes, _errors, true} -> {:ok, changes}
      {_changes, errors, false} -> {:error, errors}
    end
  end

  defp convert_params(%{__struct__: _} = params) do
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

  defp process_param(key, params, types, empty_values, opts, {changes, errors, valid?}) do
    param_key = Atom.to_string(key)
    {type, type_opts} = type!(key, types)

    case cast_field(param_key, type, type_opts, params, empty_values, opts) do
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

  defp cast_field(param_key, type, type_opts, params, empty_values, opts) do
    default_value = Keyword.get(type_opts, :default, @default_value)

    case params do
      %{^param_key => value} when default_value != @default_value and value == default_value ->
        {:ok, value}

      %{^param_key => value} ->
        if value in empty_values do
          {:error, :missing}
        else
          cast_field_value(type, value, empty_values, opts)
        end

      _ ->
        if default_value == @default_value do
          {:error, :missing}
        else
          {:ok, cast_default_value(default_value)}
        end

    end
  end

  defp cast_default_value(value) when is_function(value, 0) do
    value.()
  end
  defp cast_default_value(value) do
    value
  end

  defp cast_field_value(type, value, empty_values, opts) do
    case Construct.Type.cast(type, value, opts) do
      {:ok, value} ->
        if value in empty_values do
          {:error, :missing}
        else
          {:ok, value}
        end
      {:error, reason} ->
        {:error, reason}
      :error ->
        {:error, :invalid}
      any ->
        raise Construct.MakeError, "expected #{inspect(type)} to return {:ok, term} | {:error, term} | :error, " <>
                                   "got an unexpected value: `#{inspect(any)}`"
    end
  end
end
