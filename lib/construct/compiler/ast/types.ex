defmodule Construct.Compiler.AST.Types do
  @moduledoc false

  @builtin Construct.Type.builtin()

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
  @spec spec(Construct.Type.t()) :: Macro.t()

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

  def spec({typec, _arg}) do
    quote do
      unquote(typec).t()
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
    {type, [], []}
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
  @spec typeof(term()) :: Macro.t()

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
    if Construct.Compiler.construct_module?(term) do
      quote do
        unquote(term).t()
      end
    else
      {:atom, [], []}
    end
  end

  def typeof(term) when is_list(term) do
    {:list, [], []}
  end

  def typeof(term) when is_function(term, 0) do
    typeof(term.())
  end

  def typeof(_) do
    {:term, [], []}
  end
end
