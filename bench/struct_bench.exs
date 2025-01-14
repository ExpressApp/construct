defmodule Embedded do
  use Construct

  structure do
    field :e
  end
end

defmodule Example do
  use Construct

  structure do
    field :a
    field :b, :float
    field :c, {:map, :integer}
    field :d, Embedded
    field :e, {:map, :integer}, default: %{}
  end
end

defmodule EmbeddedFast do
  use Construct
  use Construct.Hooks.Fasten

  structure do
    field :e
  end
end

defmodule ExampleFast do
  use Construct
  use Construct.Hooks.Fasten

  structure do
    field :a
    field :b, :float
    field :c, {:map, :integer}
    field :d, EmbeddedFast
    field :e, {:map, :integer}, default: %{}
  end
end

Benchee.run(
  %{
    "make" => fn ->
      {:ok, _} = Example.make(%{a: "test", b: 1.42, c: %{a: 0, b: 42}, d: %{e: "embeds"}})
    end,

    "make fasten hook" => fn ->
      {:ok, _} = ExampleFast.make(%{a: "test", b: 1.42, c: %{a: 0, b: 42}, d: %{e: "embeds"}})
    end,
  },
  time: 3,
  memory_time: 3,
  reduction_time: 3
)
