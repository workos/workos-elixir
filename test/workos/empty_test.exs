defmodule WorkOS.EmptyTest do
  use ExUnit.Case, async: true

  alias WorkOS.Empty

  describe "struct and cast/1" do
    test "struct creation" do
      assert %Empty{status: nil} = struct(Empty)
    end

    test "cast/1 returns empty struct" do
      assert %Empty{status: nil} = Empty.cast(%{"foo" => "bar"})
      assert %Empty{status: nil} = Empty.cast(nil)
    end
  end

  describe "cast/2 with 'Accepted'" do
    test "returns struct with status 'Accepted'" do
      assert %Empty{status: "Accepted"} = Empty.cast(Empty, "Accepted")
    end
  end
end
