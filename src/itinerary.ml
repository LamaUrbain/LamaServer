open BatteriesExceptionless
open Monomorphic

type t = int

type coordinate = {x : int; y : int}

module Zoomlevel = struct
  type t = int

  let create x = x
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

  val create : float -> float -> float -> float -> itinerary
  val get_magnification : Unsigned.UInt32.t -> magnification
  val iter_coordinates : itinerary -> magnification -> (Unsigned.Size_t.t -> Unsigned.Size_t.t -> unit) -> unit
  val paint : x:int -> y:int -> width:int -> height:int -> itinerary:itinerary -> magnification:magnification -> context:Cairo.context -> bool
end = struct
  open Ctypes
  open Foreign

  type magnification = unit ptr
  type itinerary = unit ptr

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

let lol_cache = Hashtbl.create 16

let create ~starting_point:(startLat, startLon) ~ending_point:(targetLat, targetLon) =
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
