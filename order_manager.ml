open Lwt
open Hft_types

module OrderBook = Map.Make(String)

type t = {
  orders : order OrderBook.t;
  mutable position : float;
}

let create () = { orders = OrderBook.empty; position = 0.0 }

let place_order (manager : t) (order : order) =
  
  if Float.abs (manager.position +. order.qty) > 100.0 then
    Lwt.fail_with "Position limit exceeded"
  else
    let manager' = { manager with orders = OrderBook.add order.id order manager.orders } in
    Lwt.return manager'

let cancel_order (manager : t) (order_id : string) =
  { manager with orders = OrderBook.remove order_id manager.orders } |> Lwt.return