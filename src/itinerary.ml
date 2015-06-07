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
  type point
  type magnification
  type itinerary

  val init : string -> string -> bool
  val create_point : float -> float -> point
  val create : float -> float -> float -> float -> itinerary
  val get_magnification : Unsigned.UInt32.t -> magnification
  val iter_coordinates : itinerary -> magnification -> (Unsigned.Size_t.t -> Unsigned.Size_t.t -> unit) -> unit
  val paint : x:int -> y:int -> width:int -> height:int -> itinerary:itinerary -> magnification:magnification -> context:Cairo.context -> bool
end = struct
  open Ctypes
  open Foreign

  type point = unit ptr
  type magnification = unit ptr
  type itinerary = unit ptr

  let init =
    foreign "init" (string @-> string @-> returning bool)

  let create_point =
    foreign "createPoint" (float @-> float @-> returning (ptr void))

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

module PointCache = Hashtbl.Make(struct
    type t = Request_data.coord

    let equal x y =
      Float.equal x.Request_data.latitude y.Request_data.latitude
      && Float.equal x.Request_data.longitude y.Request_data.longitude

    let hash x =
      Hashtbl.hash (x.Request_data.latitude, x.Request_data.longitude)
  end)

(*
module Cache = Ocsigen_cache.Make(struct
    type key = (float * float)
    type value = t
  end)

let cache = new Cache.cache (assert false) 500
*)
let points_cache : Cpp.point PointCache.t =
  PointCache.create 16

module ItineraryCache = Hashtbl.Make(struct
    type t = (Request_data.coord * Request_data.coord)

    let equal x y =
      let aux x y =
        Float.equal x.Request_data.latitude y.Request_data.latitude
        && Float.equal x.Request_data.longitude y.Request_data.longitude
      in
      aux (fst x) (fst y) && aux (snd x) (snd y)

    let hash (x, y) =
      Hashtbl.hash Request_data.(x.latitude, x.longitude, y.latitude, y.longitude)
  end)

let itinerary_cache : Cpp.itinerary ItineraryCache.t =
  ItineraryCache.create 16

let itineraries_cache : (int, Result_data.itinerary) Hashtbl.t =
  Hashtbl.create 16

let () =
  let map = Config.map and style = Config.style in
  if not (Cpp.init map style) then
    failwith "DB init failed"

let create_point coord =
  let point =
    Cpp.create_point coord.Request_data.latitude coord.Request_data.longitude
  in
  PointCache.add points_cache coord point;
  point

let create_itinerary (departure, departure_point) (destination, destination_point) =
  let itinerary =
    Cpp.create
      departure.Request_data.latitude departure.Request_data.longitude
      destination.Request_data.latitude destination.Request_data.longitude
  in
  ItineraryCache.add itinerary_cache (departure, destination) itinerary

let create {Request_data.name; departure; destination; favorite} =
  let departure_point = create_point departure in
  let destinations = match destination with
    | Some destination ->
        let destination_point = create_point destination in
        create_itinerary
          (departure, departure_point)
          (destination, destination_point);
        [destination]
    | None ->
        []
  in
  let id = Hashtbl.length itineraries_cache in
  let res =
    { Result_data.id
    ; owner = None (* TODO *)
    ; creation = "lol" (* TODO *)
    ; favorite = false (* TODO *)
    ; departure
    ; destinations
    }
  in
  Hashtbl.add itineraries_cache id res;
  res

let waypoints_iter f l = assert false

let get_coordinates ~zoom id =
  let magnification = Cpp.get_magnification (Unsigned.UInt32.of_int zoom) in
  let itinerary = Hashtbl.find itineraries_cache id in
  let itinerary = Option.default_delayed (fun () -> assert false) itinerary in
  let set = Hashtbl.create 512 in
  waypoints_iter
    (fun path ->
       let itinerary = ItineraryCache.find itinerary_cache path in
       let aux x y = Hashtbl.replace set (x, y) () in
       Cpp.iter_coordinates itinerary magnification aux;
    )
    (itinerary.Result_data.departure :: itinerary.Result_data.destinations);
  let to_int = Unsigned.Size_t.to_int in
  Hashtbl.fold (fun (x, y) () acc -> {x = to_int x; y = to_int y} :: acc) set []

(* TODO *)
let hd = function
  | [x] -> x
  | _ -> assert false

let get_image ~x ~y ~z id =
  let itinerary = Hashtbl.find itineraries_cache id in
  let itinerary = Option.default_delayed (fun () -> assert false) itinerary in
  (* TODO *)
  let itinerary = ItineraryCache.find itinerary_cache (itinerary.Result_data.departure, hd itinerary.Result_data.destinations) in
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
