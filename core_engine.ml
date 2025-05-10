module type ORDER_TYPE = sig
  type t
  val compare : t -> t -> int
end

module type ORDER_BOOK = sig
  type t
  type order
  type trade
  
  val empty : t
  val add_order : t -> order -> t * trade list
  val best_bid : t -> float option
  val best_ask : t -> float option
end

module Order : sig
  type t = {
    id: int;
    price: float;
    quantity: int;
    is_bid: bool;
    timestamp: int;
  }
  
  val compare : t -> t -> int
end = struct
  type t = {
    id: int;
    price: float;
    quantity: int;
    is_bid: bool;
    timestamp: int;
  }

  (* Price-time priority comparison *)
  let compare a b =
    if a.is_bid <> b.is_bid then compare a.is_bid b.is_bid
    else if a.price <> b.price then
      if a.is_bid then compare b.price a.price (* Descending for bids *)
      else compare a.price b.price (* Ascending for asks *)
    else compare a.timestamp b.timestamp
end

module OrderBook : ORDER_BOOK with type order = Order.t = struct
  module OrderSet = Set.Make(Order)
  
  type order = Order.t
  type trade = {
    price: float;
    quantity: int;
    taker_id: int;
    maker_id: int;
  }

  type t = {
    bids: OrderSet.t;
    asks: OrderSet.t;
  }

  let empty = { bids = OrderSet.empty; asks = OrderSet.empty }

  let best_bid book =
    if OrderSet.is_empty book.bids then None
    else Some (OrderSet.min_elt book.bids).price

  let best_ask book =
    if OrderSet.is_empty book.asks then None
    else Some (OrderSet.min_elt book.asks).price

  let add_order book order =
    let rec match_order remaining_qty opposite_book trades =
      if remaining_qty <= 0 || OrderSet.is_empty opposite_book then
        (remaining_qty, opposite_book, trades)
      else
        let opposite_order = OrderSet.min_elt opposite_book in
        if (order.is_bid && order.price < opposite_order.price) ||
           (not order.is_bid && order.price > opposite_order.price) then
          (remaining_qty, opposite_book, trades)
        else
          let fill_qty = min remaining_qty opposite_order.quantity in
          let new_trade = {
            price = opposite_order.price;
            quantity = fill_qty;
            taker_id = order.id;
            maker_id = opposite_order.id;
          } in
          let remaining_opposite = opposite_order.quantity - fill_qty in
          let new_opposite_book = OrderSet.remove opposite_order opposite_book in
          let new_opposite_book = if remaining_opposite > 0 then
              OrderSet.add { opposite_order with quantity = remaining_opposite } new_opposite_book
            else new_opposite_book in
          match_order (remaining_qty - fill_qty) new_opposite_book (new_trade :: trades)
    in
    let (remaining_qty, new_opposite, trades) =
      if order.is_bid then
        match_order order.quantity book.asks []
      else
        match_order order.quantity book.bids []
    in
    let new_book = 
      if remaining_qty > 0 then
        let new_order = { order with quantity = remaining_qty } in
        if order.is_bid then
          { bids = OrderSet.add new_order book.bids; asks = new_opposite }
        else
          { asks = OrderSet.add new_order book.asks; bids = new_opposite }
      else
        if order.is_bid then
          { book with asks = new_opposite }
        else
          { book with bids = new_opposite }
    in
    (new_book, List.rev trades)
end

(* Market Making Strategy *)
module MarketMaker = struct
  let spread = 0.05
  let position_limit = 1000
  
  let generate_quotes book =
    let best_bid = OrderBook.best_bid book in
    let best_ask = OrderBook.best_ask book in
    match (best_bid, best_ask) with
    | (Some bb, Some ba) ->
        let mid = (bb +. ba) /. 2.0 in
        let bid_price = mid -. (spread /. 2.0) in
        let ask_price = mid +. (spread /. 2.0) in
        [
          { Order.id = 1; price = bid_price; quantity = 100; 
            is_bid = true; timestamp = 0 };
          { Order.id = 2; price = ask_price; quantity = 100; 
            is_bid = false; timestamp = 1 };
        ]
    | _ -> []
end

(* Core Engine *)
module Engine = struct
  type t = {
    order_book: OrderBook.t;
    position: int;
    pnl: float;
  }

  let initial_state = {
    order_book = OrderBook.empty;
    position = 0;
    pnl = 0.0;
  }

  let process_order state order =
    let (new_book, trades) = OrderBook.add_order state.order_book order in
    let new_position = List.fold_left (fun acc t ->
      if order.is_bid then acc + t.quantity else acc - t.quantity
    ) state.position trades in
    let new_pnl = List.fold_left (fun acc t ->
      let price_diff = if order.is_bid then t.price -. order.price else order.price -. t.price in
      acc +. (float_of_int t.quantity *. price_diff)
    ) state.pnl trades in
    { order_book = new_book; position = new_position; pnl = new_pnl }
end

(* Example Usage *)
let () =
  let engine = ref Engine.initial_state in
  let orders = [
    { Order.id = 1; price = 100.0; quantity = 100; is_bid = true; timestamp = 0 };
    { Order.id = 2; price = 101.0; quantity = 100; is_bid = false; timestamp = 1 };
  ] in
  
  List.iter (fun order ->
    engine := Engine.process_order !engine order
  ) orders;
  
  Printf.printf "Final P&L: %.2f\n" !engine.Engine.pnl