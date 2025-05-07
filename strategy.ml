(* strategy.ml *)
open Lwt
open Hft_types

let run_strategy (symbol : symbol) (data : market_data) (order_manager : Order_manager.t) =
  let spread = data.ask -. data.bid in
  if spread < 0.1 then (* Tight spread: favorable conditions *)
    let target_price = data.bid +. 0.1 in
    let order = {
      id = Uuidm.v `V4 |> Uuidm.to_string;
      symbol;
      side = Buy;
      qty = 1.0;
      price = Some target_price;
      order_type = Limit(target_price);
    } in
    Order_manager.place_order order_manager order
  else
    Lwt.return order_manager
    