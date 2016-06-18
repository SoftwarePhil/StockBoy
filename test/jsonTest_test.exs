defmodule JsonTestTest do
  def stock(name) do
    HTTPoison.get! "http://www.google.com/finance/info?q=" <> name
  end
  end
end
