defmodule Construct.Types.UUIDTest do
  use Construct.TestCase

  alias Construct.Types.UUID

  describe "#cast" do
    test "oks on a valid UUID" do
      uuid = "fd4ddf80-a7d9-4af8-b46c-26fc4566d92c"
      assert {:ok, ^uuid} = Construct.Type.cast(UUID, uuid)
    end

    test "returns an error on an invalid UUID" do
      assert :error = Construct.Type.cast(UUID, "invalid")
    end
  end
end
