defmodule Struct.Type do
  @type t         :: primitive | custom
  @type primitive :: base | composite
  @type custom    :: atom

  @typep base      :: :integer | :float | :boolean | :string | :map |
                      :binary | :decimal | :utc_datetime  |
                      :naive_datetime | :date | :time | :any
  @typep composite :: {:array, t} | {:map, t}

  @base      ~w(integer float boolean string binary decimal datetime utc_datetime naive_datetime date time map any)a
  @composite ~w(array map in)a

  @doc """
  Casts the given input to the custom type.
  """
  @callback cast(term) :: {:ok, term} | :error

  ## Functions

  @doc """
  Checks if we have a primitive type.

      iex> primitive?(:string)
      true
      iex> primitive?(Another)
      false

      iex> primitive?({:array, :string})
      true
      iex> primitive?({:array, Another})
      true

  """
  @spec primitive?(t) :: boolean
  def primitive?({composite, _}) when composite in @composite, do: true
  def primitive?(base) when base in @base, do: true
  def primitive?(_), do: false

  @doc """
  Checks if the given atom can be used as composite type.

      iex> composite?(:array)
      true
      iex> composite?(:string)
      false

  """
  @spec composite?(atom) :: boolean
  def composite?(atom), do: atom in @composite

  @doc """
  Checks if the given atom can be used as base type.

      iex> base?(:string)
      true
      iex> base?(:array)
      false
      iex> base?(Custom)
      false

  """
  @spec base?(atom) :: boolean
  def base?(atom), do: atom in @base

  @doc """
  Casts a value to the given type.

      iex> cast(:any, "whatever")
      {:ok, "whatever"}

      iex> cast(:any, nil)
      {:ok, nil}
      iex> cast(:string, nil)
      {:ok, nil}

      iex> cast(:integer, 1)
      {:ok, 1}
      iex> cast(:integer, "1")
      {:ok, 1}
      iex> cast(:integer, "1.0")
      :error

      iex> cast(:float, 1.0)
      {:ok, 1.0}
      iex> cast(:float, 1)
      {:ok, 1.0}
      iex> cast(:float, "1")
      {:ok, 1.0}
      iex> cast(:float, "1.0")
      {:ok, 1.0}
      iex> cast(:float, "1-foo")
      :error

      iex> cast(:boolean, true)
      {:ok, true}
      iex> cast(:boolean, false)
      {:ok, false}
      iex> cast(:boolean, "1")
      {:ok, true}
      iex> cast(:boolean, "0")
      {:ok, false}
      iex> cast(:boolean, "whatever")
      :error

      iex> cast(:string, "beef")
      {:ok, "beef"}
      iex> cast(:binary, "beef")
      {:ok, "beef"}

      iex> cast(:decimal, Decimal.new(1.0))
      {:ok, Decimal.new(1.0)}
      iex> cast(:decimal, Decimal.new("1.0"))
      {:ok, Decimal.new(1.0)}

      iex> cast({:array, :integer}, [1, 2, 3])
      {:ok, [1, 2, 3]}
      iex> cast({:array, :integer}, ["1", "2", "3"])
      {:ok, [1, 2, 3]}
      iex> cast({:array, :string}, [1, 2, 3])
      :error
      iex> cast(:string, [1, 2, 3])
      :error

  """
  @spec cast(t, term, [make_map: :boolean]) :: {:ok, term} | :error

  def cast({:array, type}, term, opts) when is_list(term) do
    array(term, type, &cast/3, [], opts)
  end

  def cast({:map, type}, term, opts) when is_map(term) do
    map(Map.to_list(term), type, &cast/3, %{}, opts)
  end

  def cast(type, term, opts) when is_atom(type) do
    cond do
      not primitive?(type) ->
        if function_exported?(type, :cast, 2) do
          type.cast(term, opts)
        else
          type.cast(term)
        end
      true ->
        cast(type, term)
    end
  end

  def cast(type, term, _opts) do
    cast(type, term)
  end

  @spec cast(t, term) :: {:ok, term} | :error
  def cast({:array, type}, term) when is_list(term) do
    array(term, type, &cast/3, [], [])
  end

  def cast({:map, type}, term) when is_map(term) do
    map(Map.to_list(term), type, &cast/3, %{}, [])
  end
  def cast(type, nil) do
    if primitive?(type) do
      {:ok, nil}
    else
      type.cast(nil)
    end
  end

  def cast(:float, term) when is_binary(term) do
    case Float.parse(term) do
      {float, ""} -> {:ok, float}
      _           -> :error
    end
  end
  def cast(:float, term) when is_integer(term), do: {:ok, term + 0.0}

  def cast(:boolean, term) when term in ~w(true 1),  do: {:ok, true}
  def cast(:boolean, term) when term in ~w(false 0), do: {:ok, false}

  def cast(:decimal, term) when is_binary(term) do
    Decimal.parse(term)
  end
  def cast(:decimal, term) when is_number(term) do
    {:ok, Decimal.new(term)}
  end

  def cast(:date, term) do
    cast_date(term)
  end

  def cast(:time, term) do
    cast_time(term)
  end

  def cast(:naive_datetime, term) do
    cast_naive_datetime(term)
  end

  def cast(:utc_datetime, term) do
    cast_utc_datetime(term)
  end

  def cast(:integer, term) when is_binary(term) do
    case Integer.parse(term) do
      {int, ""} -> {:ok, int}
      _         -> :error
    end
  end

  def cast(types, term) when is_list(types) do
    Enum.reduce(types, nil, fn
      (_type, {:ok, term}) ->
        {:ok, term}
      (type, _acc) ->
        case cast(type, term) do
          {:ok, term} -> {:ok, term}
          :error -> :error
        end
    end)
  end

  def cast(type, term) do
    cond do
      not primitive?(type) ->
        type.cast(term)
      of_base_type?(type, term) ->
        {:ok, term}
      true ->
        :error
    end
  end

  ## Date

  defp cast_date(binary) when is_binary(binary) do
    case Date.from_iso8601(binary) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_date(%{"year" => empty, "month" => empty, "day" => empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_date(%{year: empty, month: empty, day: empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_date(%{"year" => year, "month" => month, "day" => day}),
    do: cast_date(to_i(year), to_i(month), to_i(day))
  defp cast_date(%{year: year, month: month, day: day}),
    do: cast_date(to_i(year), to_i(month), to_i(day))
  defp cast_date(_),
    do: :error

  defp cast_date(year, month, day) when is_integer(year) and is_integer(month) and is_integer(day) do
    case Date.new(year, month, day) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_date(_, _, _),
    do: :error

  ## Time

  defp cast_time(binary) when is_binary(binary) do
    case Time.from_iso8601(binary) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_time(%{"hour" => empty, "minute" => empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_time(%{hour: empty, minute: empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_time(%{"hour" => hour, "minute" => minute} = map),
    do: cast_time(to_i(hour), to_i(minute), to_i(Map.get(map, "second")), to_i(Map.get(map, "microsecond")))
  defp cast_time(%{hour: hour, minute: minute, second: second, microsecond: {microsecond, precision}}),
    do: cast_time(to_i(hour), to_i(minute), to_i(second), {to_i(microsecond), to_i(precision)})
  defp cast_time(%{hour: hour, minute: minute} = map),
    do: cast_time(to_i(hour), to_i(minute), to_i(Map.get(map, :second)), to_i(Map.get(map, :microsecond)))
  defp cast_time(_),
    do: :error

  defp cast_time(hour, minute, sec, usec) when is_integer(usec) do
    cast_time(hour, minute, sec, {usec, 6})
  end
  defp cast_time(hour, minute, sec, nil) do
    cast_time(hour, minute, sec, {0, 0})
  end
  defp cast_time(hour, minute, sec, {usec, precision})
       when is_integer(hour) and is_integer(minute) and
            (is_integer(sec) or is_nil(sec)) and is_integer(usec) and is_integer(precision) do
    case Time.new(hour, minute, sec || 0, {usec, precision}) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_time(_, _, _, _) do
    :error
  end

  ## Naive datetime

  defp cast_naive_datetime(binary) when is_binary(binary) do
    case NaiveDateTime.from_iso8601(binary) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_naive_datetime(%{"year" => empty, "month" => empty, "day" => empty,
                             "hour" => empty, "minute" => empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_naive_datetime(%{year: empty, month: empty, day: empty,
                             hour: empty, minute: empty}) when empty in ["", nil],
    do: {:ok, nil}
  defp cast_naive_datetime(%{} = map) do
    with {:ok, date} <- cast_date(map),
         {:ok, time} <- cast_time(map) do
      case NaiveDateTime.new(date, time) do
        {:ok, _} = ok -> ok
        {:error, _} -> :error
      end
    end
  end

  ## UTC datetime

  defp cast_utc_datetime(value) do
    case cast_naive_datetime(value) do
      {:ok, %NaiveDateTime{year: year, month: month, day: day,
                           hour: hour, minute: minute, second: second, microsecond: microsecond}} ->
        {:ok, %DateTime{year: year, month: month, day: day,
                        hour: hour, minute: minute, second: second, microsecond: microsecond,
                        std_offset: 0, utc_offset: 0, zone_abbr: "UTC", time_zone: "Etc/UTC"}}
      {:ok, _} = ok ->
        ok
      :error ->
        :error
    end
  end

  ## Helpers

  # Checks if a value is of the given primitive type.
  defp of_base_type?(:any, _),           do: true
  defp of_base_type?(:id, term),         do: is_integer(term)
  defp of_base_type?(:float, term),      do: is_float(term)
  defp of_base_type?(:integer, term),    do: is_integer(term)
  defp of_base_type?(:boolean, term),    do: is_boolean(term)
  defp of_base_type?(:binary, term),     do: is_binary(term)
  defp of_base_type?(:string, term),     do: is_binary(term)
  defp of_base_type?(:map, term),        do: is_map(term) and not Map.has_key?(term, :__struct__)
  defp of_base_type?(:decimal, value),   do: match?(%{__struct__: Decimal}, value)
  defp of_base_type?(_, _),              do: false

  defp array([h|t], type, fun, acc, opts) do
    case fun.(type, h, opts) do
      {:ok, h} -> array(t, type, fun, [h|acc], opts)
      {:error, reason} -> {:error, reason}
      :error -> :error
    end
  end

  defp array([], _type, _fun, acc, _opts) do
    {:ok, Enum.reverse(acc)}
  end

  defp map(list, type, fun, acc, opts \\ [])

  defp map([{key, value} | t], type, fun, acc, opts) do
    case fun.(type, value, opts) do
      {:ok, value} -> map(t, type, fun, Map.put(acc, key, value))
      {:error, reason} -> {:error, reason}
      :error -> :error
    end
  end

  defp map([], _type, _fun, acc, _opts) do
    {:ok, acc}
  end

  defp map(_, _, _, _, _), do: :error

  defp to_i(nil), do: nil
  defp to_i(int) when is_integer(int), do: int
  defp to_i(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
