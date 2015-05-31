open Monomorphic

type coordinate = {x : int; y : int} [@@deriving yojson]
type coordinate_list = coordinate list [@@deriving yojson]

open BatteriesExceptionless

type t = int

module Zoomlevel = struct
  type t = int

  let create x =
    if Int.(x < 1 || x > 16) then
      failwith "LOL LOL";
    x
end

module Cairo_bind : sig
  type t

  val t : t Ctypes.typ

  val create : Cairo.context -> t
end = struct
  open Ctypes

  type t = unit ptr

  let t = ptr void

  external cairo_raw_address : Cairo.context -> nativeint = "cairo_address"

  let create c =
    ptr_of_raw_address (cairo_raw_address c)
end

module Cpp : sig
  type magnification
  type itinerary

  val init : string -> string -> bool
  val create : float -> float -> float -> float -> itinerary
  val get_magnification : Unsigned.UInt32.t -> magnification
  val iter_coordinates : itinerary -> magnification -> (Unsigned.Size_t.t -> Unsigned.Size_t.t -> unit) -> unit
  val paint : x:int -> y:int -> width:int -> height:int -> itinerary:itinerary -> magnification:magnification -> context:Cairo.context -> bool
end = struct
  open Ctypes
  open Foreign

  type magnification = unit ptr
  type itinerary = unit ptr

  let init =
    foreign "init" (string @-> string @-> returning bool)

  let create =
    foreign "createItinerary" (float @-> float @-> float @-> float @-> returning (ptr void))

  let get_magnification =
    foreign "getMagnification" (uint32_t @-> returning (ptr void))

  let iter_coordinates =
    foreign "iterCoordinates" (ptr void @-> ptr void @-> funptr (size_t @-> size_t @-> returning void) @-> returning void)

  let paint =
    foreign "paint" (size_t @-> size_t @-> size_t @-> size_t @-> ptr void @-> ptr void @-> Cairo_bind.t @-> returning bool)

  let paint ~x ~y ~width ~height ~itinerary ~magnification ~context =
    let context = Cairo_bind.create context in
    let x = Unsigned.Size_t.of_int x in
    let y = Unsigned.Size_t.of_int y in
    let width = Unsigned.Size_t.of_int width in
    let height = Unsigned.Size_t.of_int height in
    paint x y width height itinerary magnification context
end

(*
module Cache = Ocsigen_cache.Make(struct
    type key = (float * float)
    type value = t
  end)

let cache = new Cache.cache (assert false) 500
*)
let lol_cache : (int, Cpp.itinerary) Hashtbl.t = Hashtbl.create 16

let () =
  let map = Config.map and style = Config.style in
  if not (Cpp.init map style) then
    failwith "DB init failed"

let parse_coord x =
  let open Request_data in
  match x with
  | {typ = "address"; content = `String address} ->
      (* `Address address *)
      assert false
  | {typ = "coord"; content = `Assoc [("latitude", `Float lat); ("longitude", `Float lon)]}
  | {typ = "coord"; content = `Assoc [("longitude", `Float lon); ("latitude", `Float lat)]} ->
      `Coord (lat, lon)
  | _ ->
      failwith "Parse failed"

let create coords =
  let (`Coord (startLat, startLon), `Coord (targetLat, targetLon)) =
    let open Request_data in
    match coords with
    | {points = [start_coord; target_coord]} ->
        (parse_coord start_coord, parse_coord target_coord)
    | _ -> failwith "LOL"
  in
  let res = Cpp.create startLat startLon targetLat targetLon in
  let id = Hashtbl.length lol_cache in
  Hashtbl.add lol_cache id res;
  id

let get_coordinates ~zoom id =
  let magnification = Cpp.get_magnification (Unsigned.UInt32.of_int zoom) in
  let itinerary = Hashtbl.find lol_cache id in
  let itinerary = Option.default_delayed (fun () -> assert false) itinerary in
  let set = Hashtbl.create 512 in
  let aux x y = Hashtbl.replace set (x, y) () in
  Cpp.iter_coordinates itinerary magnification aux;
  let to_int = Unsigned.Size_t.to_int in
  Hashtbl.fold (fun (x, y) () acc -> {x = to_int x; y = to_int y} :: acc) set []

let get_image ~x ~y ~z id =
  let itinerary = Hashtbl.find lol_cache id in
  let itinerary = Option.default_delayed (fun () -> assert false) itinerary in
  let width = 256 in
  let height = 256 in
  let surface = Cairo.Image.create Cairo.Image.ARGB32 ~width ~height in
  let context = Cairo.create surface in
  let magnification = Cpp.get_magnification (Unsigned.UInt32.of_int z) in
  if Cpp.paint x y width height itinerary magnification context then
    let buf = Buffer.create 500_000 in
    Cairo.PNG.write_to_stream surface ~output:(Buffer.add_string buf);
    Buffer.contents buf
  else
    failwith "lol"
