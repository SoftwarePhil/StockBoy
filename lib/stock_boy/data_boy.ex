defmodule StockBoy.DataBoy do
  @stock_db %{protocol: "http", hostname: "localhost",database: "stocks", port: 5984}

  def stock(name) do
    HTTPoison.get!("http://www.google.com/finance/info?q=" <> name).body
    |>String.replace(~r{[\n]}, "")
    |>String.replace(~r{[//]}, "")
    |>Poison.Parser.parse!
    |>List.first
  end

  def stock_json(name) do
    HTTPoison.get!("http://www.google.com/finance/info?q=" <> name).body
    |>String.replace(~r{[\n]}, "")
    |>String.replace(~r{[//]}, "")
    |>String.replace("[", "")
    |>String.replace("]", "")
  end

  def stock_twits(name) do
    HTTPoison.get!("https://api.stocktwits.com/api/2/streams/symbol/" <> name <> ".json").body
  end

  def add(name) do
    Couchdb.Connector.Writer.create_generate(@stock_db, stock_json(name))
    Couchdb.Connector.Writer.create_generate(@stock_db, stock_twits(name))
  end

  def init_db() do
    Couchdb.Connector.Storage.storage_up(@stock_db)
  end

#don't know why this is returning a null value .. still not really
#sure about "key", the last param needed by the function
  def test do
    {:ok, result} = Couchdb.Connector.View.document_by_key(@stock_db, "stock_info", "price_date", "SGYP")
  end
end

#{:ok, result} = Couchdb.Connector.View.document_by_key(@stock_db, "stock_info", "price_name")

## :l, :e, :l_fix, :l_cur, :s, :ltt, :lt, :lt_dts, :c, :c_fix, :cp, :cp_fix, :ccol, :pcls_fix, :el, :el_fix, :el_cur, :elt, :ec, :ec_fix, :ecp, :ecp_fix, :eccol, :chg, :div, :yld]

#stock_db = %{protocol: "http", hostname: "localhost",database: "couchdb_connector_dev", port: 5984}
##(making a new database) Couchdb.Connector.Storage.storage_up(stock_db)
#Couchdb.Connector.Writer.create(db_props, "some_json_data")

# views? Queries? not sure
#http://127.0.0.1:5984/_utils/

##stocktwits
#https://api.stocktwits.com/api/2/streams/symbol/SGYP.json

##querying view
    #{:ok, result} = Couchdb.Connector.View.document_by_key(db_props, "design_name", "view_name", "key")
