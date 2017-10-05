defmodule NanoleafTest do
  use ExUnit.Case
  doctest Nanoleaf

  test "greets the world" do
    assert Nanoleaf.hello() == :world
  end
end
