open Lwt
open Hft_types

let () =
  let order_manager = Order_manager.create () in
  let market_callback data =
    Strategy.run_strategy data.symbol data order_manager >>= fun new_manager ->
    order_manager := new_manager;
    Lwt.return ()
  in

  Lwt_main.run (
    Market_feed.start_market_data_handler market_callback
  )