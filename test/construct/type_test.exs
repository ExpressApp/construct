defmodule Construct.TypeTest do
  use Construct.TestCase

  alias Construct.Type
  alias Construct.Types.CommaList

  doctest Construct.Type, import: true

  describe "#cast" do
    test "CustomType" do
      assert {:ok, []}
          == Type.cast(CustomType, [])
      assert {:error, :invalid_custom_list}
          == Type.cast(CustomType, %{})
    end

    test "EctoType" do
      assert {:ok, []}
          == Type.cast(EctoType, [])
      assert :error
          == Type.cast(EctoType, %{})
    end

    test "nil" do
      assert {:ok, nil}
          == Type.cast(:any, nil)
      assert :error
          == Type.cast(:integer, nil)
      assert {:error, :invalid_custom_list}
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

    test "{:array, CustomType}" do
      assert {:ok, [[1], [2]]}
          == Type.cast({:array, CustomType}, [[1], [2]])
      assert {:error, :invalid_custom_list}
          == Type.cast({:array, CustomType}, [nil, nil])
      assert :error
          == Type.cast({:array, CustomType}, nil)
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

    test "{:map, CustomType}" do
      assert {:ok, %{a: [[], []]}}
          == Type.cast({:map, CustomType}, %{a: [[], []]})
      assert {:error, :invalid_custom_list}
          == Type.cast({:map, CustomType}, %{a: nil})
      assert :error
          == Type.cast({:map, CustomType}, nil)
    end

    test ":struct" do
      assert {:ok, %User{name: "john"}}
          == Type.cast(:struct, %User{name: "john"})
      assert :error
          == Type.cast(:struct, %{name: "john"})
      assert :error
          == Type.cast(:struct, nil)
      assert :error
          == Type.cast(:struct, 42)
    end

    test "[CommaList, {:array, :integer}]" do
      assert {:ok, [1, 2, 3]}
          == Type.cast([CommaList, {:array, :integer}], "1,2,3")
      assert {:ok, [1]}
          == Type.cast([CommaList, {:array, :integer}], "1")
      assert :error
          == Type.cast([CommaList, {:array, :integer}], "a,b,c")
      assert :error
          == Type.cast([CommaList, {:array, :integer}], "a")
      assert {:ok, [1, 2, 3]}
          == Type.cast([CommaList, {:array, :integer}], ["1", "2", "3"])
      assert :error
          == Type.cast([CommaList, {:array, :integer}], ["a", "b", "c"])
      assert {:ok, []}
          == Type.cast([CommaList, {:array, :integer}], [])
      assert {:ok, []}
          == Type.cast([CommaList, {:array, :integer}], "")
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
      assert {:ok, Decimal.new("NaN")}
          == Type.cast(:decimal, "nan")
      assert {:ok, Decimal.new("NaN")}
          == Type.cast(:decimal, Decimal.new("NaN"))
      assert :error
          == Type.cast(:decimal, Decimal.new("Infinity"))
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
      assert {:ok, @date}
          == Type.cast(:date, "2015-12-31T00:00:00")
      assert {:ok, @date}
          == Type.cast(:date, "2015-12-31 00:00:00")
    end

    @time ~T[23:50:07]
    @time_zero ~T[23:50:00]
    @time_usec ~T[23:50:07.030000]

    test ":time" do
      assert {:ok, @time}
          == Type.cast(:time, @time)
      assert {:ok, @time_zero}
          == Type.cast(:time, @time_zero)
      assert {:ok, @time_zero}
          == Type.cast(:time, "23:50")
      assert {:ok, @time}
          == Type.cast(:time, "23:50:07")
      assert {:ok, @time}
          == Type.cast(:time, "23:50:07Z")
      assert {:ok, @time_usec}
          == Type.cast(:time, "23:50:07.030000")
      assert {:ok, @time_usec}
          == Type.cast(:time, "23:50:07.030000Z")
      assert :error
          == Type.cast(:time, "24:01")
      assert :error
          == Type.cast(:time, "00:61")
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
          == Type.cast(:naive_datetime, DateTime.from_unix!(10, :second))
      assert :error
          == Type.cast(:naive_datetime, @time)
      assert :error
          == Type.cast(:naive_datetime, 1)
      assert :error
          == Type.cast(:naive_datetime, nil)
    end

    @datetime DateTime.from_unix!(1422057007, :second)
    @datetime_zero DateTime.from_unix!(1422057000, :second)
    @datetime_usec DateTime.from_unix!(1422057007008000, :microsecond)
    @datetime_leapyear DateTime.from_unix!(951868207, :second)

    test ":utc_datetime" do
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, @datetime)
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, @datetime_usec)
      assert {:ok, @datetime}
          == Type.cast(:utc_datetime, "2015-01-24T09:50:07+10:00")
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
      assert {:ok, @datetime_usec}
          == Type.cast(:utc_datetime, "2015-01-23T17:50:07.008000-06:00")
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
          == Type.cast(:utc_datetime, 1)
      assert :error
          == Type.cast(:utc_datetime, nil)
    end

    test ":pid" do
      assert {:ok, self()}
          == Type.cast(:pid, self())
      assert :error
          == Type.cast(:pid, "#{inspect(self())}")
      assert :error
          == Type.cast(:pid, 123)
    end

    test ":reference" do
      ref = make_ref()

      assert {:ok, ref}
          == Type.cast(:reference, ref)
      assert :error
          == Type.cast(:reference, "#{inspect(ref)}")
      assert :error
          == Type.cast(:reference, 123)
    end
  end
end
