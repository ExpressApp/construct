defmodule Roadmap.OptionalRequiredTest do
  use ExUnit.Case

  # @tag :skip
  # test "Accept optional fields" do
  #   defmodule Foo do
  #     use Construct

  #     structure do
  #       field :foo, :string
  #       optional :bar, :integer
  #     end
  #   end

  #   assert {:ok, %Foo{foo: "foo", bar: 1}} = Foo.make(%{foo: "foo", bar: 1})
  #   assert {:ok, %Foo{foo: "foo", bar: nil}} = Foo.make(%{foo: "foo"})

  #   :code.delete(Roadmap.OptionalRequiredTest.Foo)
  # end

  # @tag :skip
  # test "Accept required field" do
  #   defmodule Foo do
  #     use Construct

  #     structure do
  #       required :foo, :string
  #       field :bar, :integer, default: nil
  #     end
  #   end

  #   assert {:ok, %Foo{foo: "foo", bar: 1}} = Foo.make(%{foo: "foo", bar: 1})
  #   assert {:error, %{foo: :missing}} = Foo.make(%{bar: 1})

  #   :code.delete(Roadmap.OptionalRequiredTest.Foo)
  # end
end
