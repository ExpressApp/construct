defmodule Construct.Integration.CompileHookTest do
  use Construct.TestCase

  test "compile hook pass derive down to nested structs" do
    module = create_module do
      use Construct

      structure_compile_hook :pre do
        @derive {Jason.Encoder, []}
      end

      structure do
        field :a

        field :b do
          field :ba do
            field :baa, :string, default: "test"
          end

          field :bb, :integer, default: 42
        end

        field :d do
          field :da do
            field :daa, :integer, default: 0
          end
        end
      end
    end

    assert {:ok, structure} = make(module, a: "string")

    assert json = Jason.encode!(structure)
    assert %{
      "a" => "string",
      "b" => %{"ba" => %{"baa" => "test"}, "bb" => 42},
      "d" => %{"da" => %{"daa" => 0}}
    } == Jason.decode!(json)
  end

  test "compile hook pass its ast down to nested structs" do
    module = {_, name, _, _} = create_module do
      use Construct

      structure_compile_hook :post do
        def make(params, opts) do
          with {:ok, struct} <- super(params, opts) do
            {:ok, Map.from_struct(struct)}
          end
        end
      end

      structure do
        field :a

        field :b do
          field :ba do
            field :baa, :string, default: "test"
          end

          field :bb, :integer, default: 42
        end

        field :d do
          field :da do
            field :daa, :integer, default: 0
          end
        end
      end
    end

    assert {:ok, %{
      a: "string",
      b: %{ba: %{baa: "test"}, bb: 42},
      d: %{da: %{daa: 0}}
    }} == make(module, a: "string")

    assert %{
      __struct__: name,
      a: "string",
      b: %{ba: %{baa: "test"}, bb: 42},
      d: %{da: %{daa: 0}}
    } == struct!(name, a: "string")
  end

  test "compile hook can be called twice" do
    module = create_module do
      use Construct

      structure_compile_hook :post do
        def make(params, opts) do
          with {:ok, struct} <- super(params, opts) do
            {:ok, %{struct | number: struct.number + 4}}
          end
        end

        defoverridable [make: 2]
      end

      structure_compile_hook :post do
        def make(params, opts) do
          with {:ok, struct} <- super(params, opts) do
            {:ok, %{struct | number: struct.number * 10}}
          end
        end

        defoverridable [make: 2]
      end

      structure do
        field :number, :integer
      end
    end

    assert {:ok, %{number: 150}} = make(module, number: 11)
  end

  test "throws error when trying to use structure_compile_hook/2 after structure/1" do
    assert_raise(Construct.DefinitionError, ~s(structure_compile_hook should be defined before structure itself), fn ->
      create_module do
        use Construct

        structure do
          field :test
        end

        structure_compile_hook :post do
          # ...
        end
      end
    end)
  end
end
