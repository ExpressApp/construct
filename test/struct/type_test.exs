defmodule Struct.TypeTest do
  use ExUnit.Case

  alias Struct.Type

  defmodule CustomStruct do
    def cast(params) when params == %{} do
      :error
    end
    def cast(params) do
      {:ok, params}
    end
  end

  defmodule CustomStruct2 do
    def cast(params) do
      {:ok, Map.merge(params, %{custom_struct: 2})}
    end
  end

  defmodule CustomType do
    def cast(nil) do
      :error
    end
    def cast(%{}) do
      :error
    end
    def cast(term) do
      {:ok, term}
    end
  end

  defmodule CustomTypeReason do
    def cast(term) when map_size(term) == 0 do
      {:error, :empty_map}
    end
    def cast(term) do
      {:ok, term}
    end
  end

  describe "#cast" do
    test "CustomStruct" do
      assert {:ok, :a}
          == Type.cast(CustomStruct, :a)
      assert :error
          == Type.cast(CustomStruct, %{})
    end

    test "CustomType" do
      assert {:ok, :a}
          == Type.cast(CustomType, :a)
      assert :error
          == Type.cast(CustomType, %{})
    end

    test "nil" do
      assert {:ok, nil}
          == Type.cast(:any, nil)
      assert :error
          == Type.cast(:integer, nil)
      assert :error
          == Type.cast(CustomType, nil)
    end

    test "{:array, :string}" do
      assert {:ok, ["a", "b"]}
          == Type.cast({:array, :string}, ["a", "b"])
      assert :error
          == Type.cast({:array, :string}, [1, 2])
      assert :error
          == Type.cast({:array, :string}, nil)
    end

    test "{:array, CustomTypeReason}" do
      assert {:ok, [%{a: 1}, %{b: 2}]}
          == Type.cast({:array, CustomTypeReason}, [%{a: 1}, %{b: 2}])
      assert {:error, :empty_map}
          == Type.cast({:array, CustomTypeReason}, [%{a: 1}, %{}])
      assert {:ok, [nil, nil]}
          == Type.cast({:array, CustomTypeReason}, [nil, nil])
      assert :error
          == Type.cast({:array, CustomTypeReason}, nil)
    end

    test "{:map, :string}" do
      assert {:ok, %{a: "test"}}
          == Type.cast({:map, :string}, %{a: "test"})
      assert :error
          == Type.cast({:map, :string}, %{a: :test})
      assert :error
          == Type.cast({:map, :string}, %{a: nil})
      assert :error
          == Type.cast({:map, :string}, nil)
    end

    test "{:map, CustomTypeReason}" do
      assert {:ok, %{a: %{b: 1}}}
          == Type.cast({:map, CustomTypeReason}, %{a: %{b: 1}})
      assert {:error, :empty_map}
          == Type.cast({:map, CustomTypeReason}, %{a: %{}})
      assert {:ok, %{a: nil}}
          == Type.cast({:map, CustomTypeReason}, %{a: nil})
      assert :error
          == Type.cast({:map, CustomTypeReason}, nil)
    end

    test ":float" do
      assert {:ok, 1.42}
          == Type.cast(:float, "1.42")
      assert {:ok, 1.0}
          == Type.cast(:float, 1)
      assert :error
          == Type.cast(:float, nil)
    end

    test ":boolean" do
      assert {:ok, true}
          == Type.cast(:boolean, "1")
      assert {:ok, true}
          == Type.cast(:boolean, "true")
      assert {:ok, false}
          == Type.cast(:boolean, "0")
      assert {:ok, false}
          == Type.cast(:boolean, "false")
      assert :error
          == Type.cast(:boolean, nil)
    end

    test ":integer" do
      assert {:ok, 42}
          == Type.cast(:integer, "42")
      assert :error
          == Type.cast(:integer, nil)
    end

    test ":decimal" do
      assert {:ok, Decimal.new("1.0")}
          == Type.cast(:decimal, "1.0")
      assert {:ok, Decimal.new("1.0")}
          == Type.cast(:decimal, 1.0)
      assert {:ok, Decimal.new("1")}
          == Type.cast(:decimal, 1)
      assert {:ok, Decimal.new("1")}
          == Type.cast(:decimal, Decimal.new("1"))
      assert :error
          == Type.cast(:decimal, nil)
    end

    @date ~D[2015-12-31]
    @leap_date ~D[2000-02-29]
    @date_unix_epoch ~D[1970-01-01]

    test ":date" do
      assert {:ok, @date}
          == Type.cast(:date, @date)
      assert {:ok, @date}
          == Type.cast(:date, "2015-12-31")
      assert {:ok, @leap_date}
          == Type.cast(:date, "2000-02-29")
      assert :error
          == Type.cast(:date, "2015-00-23")
      assert :error
          == Type.cast(:date, "2015-13-23")
      assert :error
          == Type.cast(:date, "2015-01-00")
      assert :error
          == Type.cast(:date, "2015-01-32")
      assert :error
          == Type.cast(:date, "2015-02-29")
      assert :error
          == Type.cast(:date, "1900-02-29")
      assert {:ok, @date}
          == Type.cast(:date, %{"year" => "2015", "month" => "12", "day" => "31"})
      assert {:ok, @date}
          == Type.cast(:date, %{year: 2015, month: 12, day: 31})
      assert {:ok, nil}
          == Type.cast(:date, %{"year" => "", "month" => "", "day" => ""})
      assert {:ok, nil}
          == Type.cast(:date, %{year: nil, month: nil, day: nil})
      assert :error
          == Type.cast(:date, %{"year" => "2015", "month" => "", "day" => "31"})
      assert :error
          == Type.cast(:date, %{"year" => "2015", "month" => nil, "day" => "31"})
      assert :error
          == Type.cast(:date, %{"year" => "2015", "month" => nil})
      assert :error
          == Type.cast(:date, %{"year" => "", "month" => "01", "day" => "30"})
      assert :error
          == Type.cast(:date, %{"year" => nil, "month" => "01", "day" => "30"})
      assert {:ok, @date_unix_epoch}
          == Type.cast(:date, DateTime.from_unix!(10))
      assert {:ok, @date_unix_epoch}
          == Type.cast(:date, ~N[1970-01-01 12:23:34])
      assert {:ok, @date}
          == Type.cast(:date, @date)
      assert :error
          == Type.cast(:date, ~T[12:23:34])
      assert :error
          == Type.cast(:date, nil)
    end

    @time ~T[23:50:07]
    @time_zero ~T[23:50:00]
    @time_usec ~T[23:50:07.030000]

    test ":time" do
      assert {:ok, @time}
          == Type.cast(:time, @time)
      assert  {:ok, @time_zero}
          == Type.cast(:time, @time_zero)
      assert {:ok, @time}
          == Type.cast(:time, "23:50:07")
      assert {:ok, @time}
          == Type.cast(:time, "23:50:07Z")
      assert {:ok, @time_usec}
          == Type.cast(:time, "23:50:07.030000")
      assert {:ok, @time_usec}
          == Type.cast(:time, "23:50:07.030000Z")
      assert :error
          == Type.cast(:time, "24:01:01")
      assert :error
          == Type.cast(:time, "00:61:00")
      assert :error
          == Type.cast(:time, "00:00:61")
      assert :error
          == Type.cast(:time, "00:00:009")
      assert :error
          == Type.cast(:time, "00:00:00.A00")
      assert {:ok, @time}
          == Type.cast(:time, %{"hour" => "23", "minute" => "50", "second" => "07"})
      assert {:ok, @time}
          == Type.cast(:time, %{hour: 23, minute: 50, second: 07})
      assert {:ok, nil}
          == Type.cast(:time, %{"hour" => "", "minute" => ""})
      assert {:ok, nil}
          == Type.cast(:time, %{hour: nil, minute: nil})
      assert {:ok, @time_zero}
          == Type.cast(:time, %{"hour" => "23", "minute" => "50"})
      assert {:ok, @time_zero}
          == Type.cast(:time, %{hour: 23, minute: 50})
      assert {:ok, @time_usec}
          == Type.cast(:time, %{hour: 23, minute: 50, second: 07, microsecond: 30_000})
      assert {:ok, @time_usec}
          == Type.cast(:time, %{"hour" => 23, "minute" => 50, "second" => 07, "microsecond" => 30_000})
      assert :error
          == Type.cast(:time, %{"hour" => "", "minute" => "50"})
      assert :error
          == Type.cast(:time, %{hour: 23, minute: nil})
      assert {:ok, ~T[23:30:10]}
          == Type.cast(:time, ~N[2016-11-11 23:30:10])
      assert :error
          == Type.cast(:time, ~D[2016-11-11])
      assert :error
          == Type.cast(:time, nil)
    end

    @datetime ~N[2015-01-23 23:50:07]
    @datetime_zero ~N[2015-01-23 23:50:00]
    @datetime_usec ~N[2015-01-23 23:50:07.008000]
    @datetime_leapyear ~N[2000-02-29 23:50:07]

    test ":naive_datetime" do
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, @datetime)
      assert {:ok, @datetime_usec}
          == Type.cast(:naive_datetime, @datetime_usec)
      assert {:ok, @datetime_leapyear}
          == Type.cast(:naive_datetime, @datetime_leapyear)
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, "2015-01-23 23:50:07")
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, "2015-01-23T23:50:07")
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, "2015-01-23T23:50:07Z")
      assert {:ok, @datetime_leapyear}
          == Type.cast(:naive_datetime, "2000-02-29T23:50:07")
      assert :error
          == Type.cast(:naive_datetime, "2015-01-23P23:50:07")
      assert {:ok, @datetime_usec}
          == Type.cast(:naive_datetime, "2015-01-23T23:50:07.008000")
      assert {:ok, @datetime_usec}
          == Type.cast(:naive_datetime, "2015-01-23T23:50:07.008000Z")
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                          "hour" => "23", "minute" => "50", "second" => "07"})
      assert {:ok, @datetime}
          == Type.cast(:naive_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: 50, second: 07})
      assert {:ok, nil}
          == Type.cast(:naive_datetime, %{"year" => "", "month" => "", "day" => "",
                                          "hour" => "", "minute" => ""})
      assert {:ok, nil}
          == Type.cast(:naive_datetime, %{year: nil, month: nil, day: nil, hour: nil, minute: nil})
      assert {:ok, @datetime_zero}
          == Type.cast(:naive_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                          "hour" => "23", "minute" => "50"})
      assert {:ok, @datetime_zero}
          == Type.cast(:naive_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: 50})
      assert {:ok, @datetime_usec}
          == Type.cast(:naive_datetime, %{year: 2015, month: 1, day: 23, hour: 23,
                                          minute: 50, second: 07, microsecond: 8_000})
      assert {:ok, @datetime_usec}
          == Type.cast(:naive_datetime, %{"year" => 2015, "month" => 1, "day" => 23,
                                          "hour" => 23, "minute" => 50, "second" => 07,
                                          "microsecond" => 8_000})
      assert :error
          == Type.cast(:naive_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                          "hour" => "", "minute" => "50"})
      assert :error
          == Type.cast(:naive_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: nil})
      assert {:ok, ~N[1970-01-01 00:00:10]}
          == Type.cast(:naive_datetime, DateTime.from_unix!(10, :seconds))
      assert :error
          == Type.cast(:naive_datetime, @time)
      assert :error
          == Type.cast(:naive_datetime, nil)
    end

    @datetime DateTime.from_unix!(1422057007, :seconds)
    @datetime_zero DateTime.from_unix!(1422057000, :seconds)
    @datetime_usec DateTime.from_unix!(1422057007008000, :microseconds)
    @datetime_leapyear DateTime.from_unix!(951868207, :seconds)

    test ":utc_datetime" do
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, @datetime)
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, @datetime_usec)
      assert {:ok, @datetime_leapyear}
          == Type.cast(:utc_datetime, @datetime_leapyear)
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, "2015-01-23 23:50:07")
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, "2015-01-23T23:50:07")
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, "2015-01-23T23:50:07Z")
      assert {:ok, @datetime_leapyear}
          == Type.cast(:utc_datetime, "2000-02-29T23:50:07")
      assert :error
          == Type.cast(:utc_datetime, "2015-01-23P23:50:07")
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, "2015-01-23T23:50:07.008000")
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, "2015-01-23T23:50:07.008000Z")
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                        "hour" => "23", "minute" => "50", "second" => "07"})
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: 50, second: 07})
      assert {:ok, nil}
          == Type.cast(:utc_datetime, %{"year" => "", "month" => "", "day" => "",
                                        "hour" => "", "minute" => ""})
      assert {:ok, nil}
          == Type.cast(:utc_datetime, %{year: nil, month: nil, day: nil, hour: nil, minute: nil})
      assert {:ok, @datetime_zero}
          == Type.cast(:utc_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                        "hour" => "23", "minute" => "50"})
      assert {:ok, @datetime_zero}
          == Type.cast(:utc_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: 50})
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, %{year: 2015, month: 1, day: 23, hour: 23,
                                        minute: 50, second: 07, microsecond: 8_000})
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, %{"year" => 2015, "month" => 1, "day" => 23,
                                        "hour" => 23, "minute" => 50, "second" => 07,
                                        "microsecond" => 8_000})
      assert :error
          == Type.cast(:utc_datetime, %{"year" => "2015", "month" => "1", "day" => "23",
                                        "hour" => "", "minute" => "50"})
      assert :error
          == Type.cast(:utc_datetime, %{year: 2015, month: 1, day: 23, hour: 23, minute: nil})
      assert :error
          == Type.cast(:utc_datetime, ~T[12:23:34])
      assert :error
          == Type.cast(:utc_datetime, nil)
    end
  end
end
