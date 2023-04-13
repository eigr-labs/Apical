defmodule ApicalTest.Parser.QueryParserTest do
  use ExUnit.Case, async: true

  alias Apical.Parser.Query

  describe "for the query parser - basics" do
    test "it works with empty string" do
      assert {:ok, %{}} = Query.parse("")
    end

    test "it works with basic one key parameter" do
      assert {:ok, %{"foo" => "bar"}} = Query.parse("foo=bar")
    end

    test "it works with basic multi key thing" do
      assert {:ok, %{"foo" => "bar"}} = Query.parse("foo=bar&baz=quux")
    end

    test "percent encoding works" do
      assert {:ok, %{"foo" => "bar baz"}} = Query.parse("foo=bar%20baz")
    end
  end

  describe "exceptions with strange value strings" do
    test "value with no key defaults to empty string" do
      assert {:ok, %{"foo" => ""}} = Query.parse("foo=")
    end

    test "standalone value with no key defaults to nil" do
      assert {:ok, %{"foo" => nil}} = Query.parse("foo")
    end
  end

  describe "array encoding" do
    test "with form encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:array], style: :form}})
    end

    test "with space delimited encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%20baz", %{"foo" => %{type: [:array], style: :space_delimited}})
    end

    test "with pipe delimited encoding" do
      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%7Cbaz", %{"foo" => %{type: [:array], style: :pipe_delimited}})

      assert {:ok, %{"foo" => ["bar", "baz"]}} =
               Query.parse("foo=bar%7cbaz", %{"foo" => %{type: [:array], style: :pipe_delimited}})
    end
  end

  describe "object encoding" do
    test "with form encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar,baz", %{"foo" => %{type: [:object], style: :form}})

      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo=bar,baz,quux,mlem", %{"foo" => %{type: [:object], style: :form}})
    end

    test "with space delimited encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%20baz", %{
                 "foo" => %{type: [:object], style: :space_delimited}
               })
    end

    test "with pipe delimited encoding" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%7Cbaz", %{"foo" => %{type: [:object], style: :pipe_delimited}})

      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo=bar%7cbaz", %{"foo" => %{type: [:object], style: :pipe_delimited}})
    end
  end

  describe "deep object encoding" do
    test "works" do
      assert {:ok, %{"foo" => %{"bar" => "baz"}}} =
               Query.parse("foo[bar]=baz", %{deep_object_keys: ["foo"]})

      assert {:ok, %{"foo" => %{"bar" => "baz", "quux" => "mlem"}}} =
               Query.parse("foo[bar]=baz&foo[quux]=mlem", %{deep_object_keys: ["foo"]})
    end
  end
end
