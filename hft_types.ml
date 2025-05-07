type symbol = BTCUSD | ETHUSD | SOLUSD [@@deriving show]

type order_type =
  | Market
  | Limit of float

type order_side =
  | Buy
  | Sell

type order = {
  id : string;
  symbol : symbol;
  side : order_side;
  qty : float;
  price : float option;
  order_type : order_type;
} [@@deriving yojson]

type market_data = {
  symbol : symbol;
  bid : float;
  ask : float;
  timestamp : int64;
} [@@deriving yojson]