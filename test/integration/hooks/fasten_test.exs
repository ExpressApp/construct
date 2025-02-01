defmodule Construct.Integration.Hooks.FastenTest do
  use Construct.TestCase

  defmodule IP do
    @behaviour Construct.Type

    def cast(term) when is_binary(term) do
      :inet.parse_address(String.to_charlist(term))
    end

    def cast(_) do
      :error
    end
  end

  defmodule User do
    use Construct
    use Construct.Hooks.Fasten

    structure do
      field :huid, :string
      field :ip, IP
    end
  end

  test "#make returns structs with anonymous functions" do
    params = %{
      "huid" => "9767dcf6-9413-44dd-af9a-2af0188ae12b",
      "ip" => "127.0.0.1"
    }

    assert {:ok, %User{
      huid: params["huid"],
      ip: {127, 0, 0, 1}
    }} == User.make(params)
  end

  test "#make with invalid params" do
    assert {:error, %{huid: :invalid}} =
      User.make(%{"huid" => 42, "ip" => 42})

    assert {:error, %{huid: :invalid}} =
      User.make(%{"huid" => 42, "ip" => "127.0.0.1.1"})

    assert {:error, %{ip: :einval}} =
      User.make(%{"huid" => "9767dcf6-9413-44dd-af9a-2af0188ae12b", "ip" => "127.0.0.1.1"})
  end
end
