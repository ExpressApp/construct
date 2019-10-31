defmodule Construct.Type do
  @moduledoc """
  Type-coercion module, originally copied and modified from
  [Ecto.Type](https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/type.ex)
  and behaviour to implement your own types.

  ## Defining custom types

      defmodule CustomType do
        @behaviour Construct.Type

        def cast(value) do
          {:ok, value}
        end
      end
  """

  @type t       :: builtin | custom | list(builtin | custom)
  @type custom  :: module | Construct.t
  @type builtin :: :integer | :float | :boolean | :string |
                   :binary | :pid | :reference | :decimal | :utc_datetime |
                   :naive_datetime | :date | :time | :any |
                   :array | {:array, t} | :map | {:map, t} | :struct

  @type cast_ret :: {:ok, term} | {:error, term} | :error

  @builtin ~w(
    integer float boolean string binary pid reference decimal
    utc_datetime naive_datetime date time any array map struct
  )a

  @doc """
  Casts the given input to the custom type.
  """
  @callback cast(term) :: cast_ret

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

      iex> primitive?([Another, {:array, :integer}])
      false
  """
  @spec primitive?(t) :: boolean
  def primitive?({type, _}) when type in @builtin, do: true
  def primitive?(type) when type in @builtin, do: true
  def primitive?(_), do: false

  @doc """
  Casts a value to the given type.

      iex> cast(:any, "whatever")
      {:ok, "whatever"}

      iex> cast(:any, nil)
      {:ok, nil}
      iex> cast(:string, nil)
      :error

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
      iex> cast(:decimal, 1.0)
      {:ok, Decimal.new(1.0)}
      iex> cast(:decimal, "1.0")
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
  @spec cast(t, term, options) :: cast_ret | any
    when options: [make_map: boolean]

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

  @doc """
  Behaves like `cast/3`, but without options provided to nested types.
  """
  @spec cast(t, term) :: cast_ret | any

  def cast(type, term)

  def cast(types, term) when is_map(types) do
    if is_map(term) or is_list(term) do
      Construct.Cast.make(types, term)
    else
      :error
    end
  end

  def cast(types, term) when is_list(types) do
    Enum.reduce(types, {:ok, term}, fn
      (type, {:ok, term}) -> cast(type, term)
      (_, ret) -> ret
    end)
  end

  def cast({:array, type}, term) when is_list(term) do
    array(term, type, &cast/3, [], [])
  end

  def cast({:map, type}, term) when is_map(term) do
    map(Map.to_list(term), type, &cast/3, %{}, [])
  end

  def cast(:float, term) when is_binary(term) do
    case Float.parse(term) do
      {float, ""} -> {:ok, float}
      _           -> :error
    end
  end
  def cast(:float, term) when is_integer(term), do: {:ok, :erlang.float(term)}

  def cast(:boolean, term) when term in ~w(true 1),  do: {:ok, true}
  def cast(:boolean, term) when term in ~w(false 0), do: {:ok, false}

  def cast(:pid, term) when is_pid(term), do: {:ok, term}

  def cast(:reference, term) when is_reference(term), do: {:ok, term}

  def cast(:decimal, term) when is_binary(term) do
    apply(Decimal, :parse, [term])
    |> validate_decimal()
  end
  def cast(:decimal, term) when is_integer(term) do
    {:ok, apply(Decimal, :new, [term])}
  end
  def cast(:decimal, term) when is_float(term) do
    {:ok, apply(Decimal, :from_float, [term])}
  end
  def cast(:decimal, %{__struct__: Decimal} = term) do
    validate_decimal({:ok, term})
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
      {:ok, _} = ok ->
        ok
      {:error, _} ->
        case NaiveDateTime.from_iso8601(binary) do
          {:ok, naive_datetime} -> {:ok, NaiveDateTime.to_date(naive_datetime)}
          {:error, _} -> :error
        end
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

  defp cast_time(<<hour::2-bytes, ?:, minute::2-bytes>>),
    do: cast_time(to_i(hour), to_i(minute), 0, nil)
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

  defp cast_naive_datetime(nil) do
    :error
  end
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
      NaiveDateTime.new(date, time)
    end
  end
  defp cast_naive_datetime(_) do
    :error
  end

  ## UTC datetime

  defp cast_utc_datetime(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(binary) do
          {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
          {:error, _} -> :error
        end
      {:error, _} -> :error
    end
  end
  defp cast_utc_datetime(%DateTime{time_zone: "Etc/UTC"} = datetime), do: {:ok, datetime}
  defp cast_utc_datetime(%DateTime{} = datetime) do
    case (datetime |> DateTime.to_unix() |> DateTime.from_unix()) do
      {:ok, _} = ok -> ok
      {:error, _} -> :error
    end
  end
  defp cast_utc_datetime(value) do
    case cast_naive_datetime(value) do
      {:ok, %NaiveDateTime{} = naive_datetime} ->
        {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
      {:ok, _} = ok ->
        ok
      :error ->
        :error
    end
  end

  ## Typespecs

  @doc """
  Returns typespec AST for given type

    iex> spec([CommaList, {:array, :integer}]) |> Macro.to_string()
    "list(:integer)"

    iex> spec({:array, :string}) |> Macro.to_string()
    "list(String.t())"

    iex> spec({:map, CustomType}) |> Macro.to_string()
    "%{optional(term) => CustomType.t()}"

    iex> spec(:string) |> Macro.to_string()
    "String.t()"

    iex> spec(CustomType) |> Macro.to_string()
    "CustomType.t()"
  """
  @spec spec(t) :: Macro.t()

  def spec(type) when is_list(type) do
    type |> List.last() |> spec()
  end

  def spec({:array, type}) do
    quote do
      list(unquote(spec(type)))
    end
  end

  def spec({:map, type}) do
    quote do
      %{optional(term) => unquote(spec(type))}
    end
  end

  def spec(:string) do
    quote do
      String.t()
    end
  end

  def spec(:decimal) do
    quote do
      Decimal.t()
    end
  end

  def spec(:utc_datetime) do
    quote do
      DateTime.t()
    end
  end

  def spec(:naive_datetime) do
    quote do
      NaiveDateTime.t()
    end
  end

  def spec(:date) do
    quote do
      Date.t()
    end
  end

  def spec(:time) do
    quote do
      Time.t()
    end
  end

  def spec(type) when type in @builtin do
    type
  end

  def spec(type) when is_atom(type) do
    quote do
      unquote(type).t()
    end
  end

  def spec(type) do
    type
  end

  @doc """
  Returns typespec AST for given term

    iex> typeof(nil) |> Macro.to_string()
    "nil"

    iex> typeof(1.42) |> Macro.to_string()
    "float()"

    iex> typeof("string") |> Macro.to_string()
    "String.t()"

    iex> typeof(CustomType) |> Macro.to_string()
    "CustomType.t()"

    iex> typeof(&NaiveDateTime.utc_now/0) |> Macro.to_string()
    "NaiveDateTime.t()"
  """
  @spec spec(t) :: Macro.t()

  def typeof(term) when is_nil(term) do
    nil
  end

  def typeof(term) when is_integer(term) do
    {:integer, [], []}
  end

  def typeof(term) when is_float(term) do
    {:float, [], []}
  end

  def typeof(term) when is_boolean(term) do
    {:boolean, [], []}
  end

  def typeof(term) when is_binary(term) do
    quote do
      String.t()
    end
  end

  def typeof(term) when is_pid(term) do
    {:pid, [], []}
  end

  def typeof(term) when is_reference(term) do
    {:reference, [], []}
  end

  def typeof(%{__struct__: struct}) when is_atom(struct) do
    quote do
      unquote(struct).t()
    end
  end

  def typeof(term) when is_map(term) do
    {:map, [], []}
  end

  def typeof(term) when is_atom(term) do
    quote do
      unquote(term).t()
    end
  end

  def typeof(term) when is_list(term) do
    {:list, [], []}
  end

  def typeof(term) when is_function(term, 0) do
    term.() |> typeof()
  end

  def typeof(_) do
    {:term, [], []}
  end

  ## Helpers

  defp validate_decimal({:ok, %{__struct__: Decimal, coef: coef}}) when coef in [:inf, :qNaN, :sNaN],
    do: :error
  defp validate_decimal(value),
    do: value

  # Checks if a value is of the given primitive type.
  defp of_base_type?(:any, _),           do: true
  defp of_base_type?(:float, term),      do: is_float(term)
  defp of_base_type?(:integer, term),    do: is_integer(term)
  defp of_base_type?(:boolean, term),    do: is_boolean(term)
  defp of_base_type?(:binary, term),     do: is_binary(term)
  defp of_base_type?(:string, term),     do: is_binary(term)
  defp of_base_type?(:map, term),        do: is_map(term) and not Map.has_key?(term, :__struct__)
  defp of_base_type?(:struct, term),     do: is_map(term) and Map.has_key?(term, :__struct__)
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

  defp to_i(nil), do: nil
  defp to_i(int) when is_integer(int), do: int
  defp to_i(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
