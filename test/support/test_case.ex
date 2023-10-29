defmodule WorkOS.TestCase do
  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      import WorkOS.TestCase
    end
  end
end
