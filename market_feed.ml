(* market_feed.ml *)
open Lwt
open Hft_types

let mock_market_data () =
  (* Simulate real-time updates *)
  let symbols = [BTCUSD; ETHUSD; SOLUSD] in
  Lwt_stream.from (fun () ->
      let symbol = List.nth symbols (Random.int (List.length symbols)) in
      let bid = 1000.0 +. (Random.float 50.0) in
      let ask = bid +. 0.5 in
      Lwt.return_some { symbol; bid; ask; timestamp = Unix.gettimeofday() |> Int64.of_float }
    )

let start_market_data_handler (callback : market_data -> unit Lwt.t) =
  let stream = mock_market_data () in
  Lwt_stream.iter_s callback stream