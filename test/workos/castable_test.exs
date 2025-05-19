defmodule WorkOS.CastableTest do
  use ExUnit.Case, async: true

  alias WorkOS.Castable

  defmodule Dummy do
    defstruct [:foo]

    def cast(map) do
      %__MODULE__{foo: map["foo"]}
    end
  end

  describe "cast/2" do
    test "returns nil when given nil" do
      assert Castable.cast(Dummy, nil) == nil
    end

    test "returns map when :raw is used" do
      map = %{"foo" => "bar"}
      assert Castable.cast(:raw, map) == map
    end

    test "calls cast/2 for tuple implementation" do
      inner = Dummy
      map = %{"foo" => "bar"}

      defmodule Outer do
        def cast({Dummy, m}), do: Dummy.cast(m)
      end

      assert %Dummy{foo: "bar"} = Castable.cast({Outer, Dummy}, map)
    end

    test "calls cast/2 for module implementation" do
      map = %{"foo" => "bar"}
      assert %Dummy{foo: "bar"} = Castable.cast(Dummy, map)
    end

    test "special case for WorkOS.Empty and 'Accepted'" do
      assert %WorkOS.Empty{status: "Accepted"} = Castable.cast(WorkOS.Empty, "Accepted")
    end
  end

  describe "cast_list/2" do
    test "returns nil when given nil" do
      assert Castable.cast_list(Dummy, nil) == nil
    end

    test "casts a list of maps to structs" do
      list = [%{"foo" => "a"}, %{"foo" => "b"}]
      result = Castable.cast_list(Dummy, list)
      assert [%Dummy{foo: "a"}, %Dummy{foo: "b"}] = result
    end
  end
end
