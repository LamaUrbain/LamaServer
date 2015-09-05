module Db = Db.Db(Db_macaque)

open Lwt.Infix
open Monomorphic

type coordinate = {x : int; y : int} [@@deriving yojson]
type coordinate_list = coordinate list [@@deriving yojson]
type itineraries = Result_data.itinerary list [@@deriving yojson]

open BatteriesExceptionless

type t = int32

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
  type map_data
  type point
  type magnification
  type itinerary

  val init : string -> string -> bool
  val create_point : float -> float -> point
  val create : point -> point -> itinerary
  val get_magnification : Unsigned.UInt32.t -> magnification
  val iter_coordinates : itinerary -> magnification -> (Unsigned.Size_t.t -> Unsigned.Size_t.t -> unit) -> unit
  val create_map_data : unit -> map_data
  val add_map_data : map_data -> itinerary -> unit
  val paint : x:int -> y:int -> width:int -> height:int -> map_data:map_data -> magnification:magnification -> context:Cairo.context -> bool
end = struct
  open Ctypes
  open Foreign

  type map_data = unit ptr
  type point = unit ptr
  type magnification = unit ptr
  type itinerary = unit ptr

  let init =
    foreign "init" (string @-> string @-> returning bool)

  let create_point =
    foreign "createPoint" (float @-> float @-> returning (ptr void))

  let create =
    foreign "createItinerary" (ptr void @-> ptr void @-> returning (ptr void))

  let get_magnification =
    foreign "getMagnification" (uint32_t @-> returning (ptr void))

  let iter_coordinates =
    foreign "iterCoordinates" (ptr void @-> ptr void @-> funptr (size_t @-> size_t @-> returning void) @-> returning void)

  let create_map_data =
    foreign "createMapData" (void @-> returning (ptr void))

  let add_map_data =
    foreign "addMapData" (ptr void @-> ptr void @-> returning void)

  let paint =
    foreign "paint" (size_t @-> size_t @-> size_t @-> size_t @-> ptr void @-> ptr void @-> Cairo_bind.t @-> returning bool)

  let paint ~x ~y ~width ~height ~map_data ~magnification ~context =
    let context = Cairo_bind.create context in
    let x = Unsigned.Size_t.of_int x in
    let y = Unsigned.Size_t.of_int y in
    let width = Unsigned.Size_t.of_int width in
    let height = Unsigned.Size_t.of_int height in
    paint x y width height map_data magnification context
end

(*
module Cache = Ocsigen_cache.Make(struct
    type key = (float * float)
    type value = t
  end)

let cache = new Cache.cache (assert false) 500
*)

module PointCache : sig
  val find : Request_data.coord -> Cpp.point
end = struct
  module H = Hashtbl.Make(struct
      type t = Request_data.coord

      let equal x y =
        Float.equal x.Request_data.latitude y.Request_data.latitude
        && Float.equal x.Request_data.longitude y.Request_data.longitude

      let hash x =
        Hashtbl.hash (x.Request_data.latitude, x.Request_data.longitude)
    end)

  let self = H.create 16

  let find k =
    match H.find self k with
    | point ->
        point
    | exception Not_found ->
        let latitude = k.Request_data.latitude in
        let longitude = k.Request_data.longitude in
        let point = Cpp.create_point latitude longitude in
        H.add self k point;
        point
end

module ItineraryCache : sig
  val find : (Request_data.coord * Request_data.coord) -> Cpp.itinerary
  val add : (Request_data.coord * Request_data.coord) -> unit
end = struct
  module H = Hashtbl.Make(struct
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

  let self = H.create 16

  let find ((departure, destination) as path) =
    match H.find self path with
    | itinerary ->
        itinerary
    | exception Not_found ->
        let departure_point = PointCache.find departure in
        let destination_point = PointCache.find destination in
        let itinerary = Cpp.create departure_point destination_point in
        H.add self path itinerary;
        itinerary

  let add path = ignore (find path)
end

let () =
  let map = Config.map and style = Config.style in
  if not (Cpp.init map style) then
    failwith "DB init failed"

let create {Request_data.name; departure; destination; favorite} =
  let destinations = match destination with
    | Some destination ->
        ItineraryCache.add (departure, destination);
        [destination]
    | None ->
        []
  in
  Db.create_itinerary
    ~owner:None (* TODO *)
    ~name
    ~favorite
    ~departure
    ~destinations

let rec waypoints_iter f = function
  | [] -> ()
  | [_] -> ()
  | x::((y::_) as xs) -> f (x, y); waypoints_iter f xs

let recache_itineraries itinerary =
  waypoints_iter
    ItineraryCache.add
    (itinerary.Result_data.departure :: itinerary.Result_data.destinations)

let get_coordinates ~zoom id =
  let magnification = Cpp.get_magnification (Unsigned.UInt32.of_int zoom) in
  Db.get_itinerary id >>= fun it ->
  match it with
  | Some itinerary -> (
    let set = Hashtbl.create 512 in
    waypoints_iter
      (fun path ->
         let itinerary = ItineraryCache.find path in
         let aux x y = Hashtbl.replace set (x, y) () in
        Cpp.iter_coordinates itinerary magnification aux;
      )
      (itinerary.Result_data.departure :: itinerary.Result_data.destinations);
  let to_int = Unsigned.Size_t.to_int in
  Lwt.return (Hashtbl.fold (fun (x, y) () acc -> {x = to_int x; y = to_int y} :: acc) set []))
  | None -> Lwt.fail_with "Lol"

let get id = Db.get_itinerary id >>= fun i ->
  match i with
  | Some i -> Lwt.return i
  | None -> Lwt.fail_with "Itinerary not found"

let get_image ~x ~y ~z id =
  get id >>= fun itinerary ->
  let map_data = Cpp.create_map_data () in
  waypoints_iter
    (fun path ->
       let itinerary = ItineraryCache.find path in
       Cpp.add_map_data map_data itinerary;
    )
    (itinerary.Result_data.departure :: itinerary.Result_data.destinations);
  let width = 256 in
  let height = 256 in
  let surface = Cairo.Image.create Cairo.Image.ARGB32 ~width ~height in
  let context = Cairo.create surface in
  let magnification = Cpp.get_magnification (Unsigned.UInt32.of_int z) in
  if Cpp.paint x y width height map_data magnification context then
    let buf = Buffer.create 500_000 in
    Cairo.PNG.write_to_stream surface ~output:(Buffer.add_string buf);
    Lwt.return (Buffer.contents buf)
  else
    Lwt.fail_with "lol"

let get_all {Request_data.search; owner; favorite; ordering} =
  Db.get_all_itineraries () >>= fun itineraries ->
  let itineraries = match search with
    | Some search ->
        List.filter
          (fun x -> Option.map_default (String.equal search) false x.Result_data.name)
          itineraries
    | None ->
        itineraries
  in
  let itineraries = match owner with
    | Some owner ->
        List.filter
          (fun x -> Option.map_default (String.equal owner) false x.Result_data.owner)
          itineraries
    | None ->
        itineraries
  in
  let itineraries = match favorite with
    | Some favorite ->
        List.filter
          (fun x -> Option.map_default (Bool.equal favorite) false x.Result_data.favorite)
          itineraries
    | None ->
        itineraries
  in
  let itineraries = match ordering with
    | Some "name" ->
        List.sort
          (fun x y ->
             Option.map_default
               (fun x ->
                  Option.map_default (String.compare x) 1 y.Result_data.name
               )
               (-1)
               x.Result_data.name
          )
          itineraries
    | Some "creation" ->
        List.sort
          (fun x y -> String.compare x.Result_data.creation y.Result_data.creation)
          itineraries
    | Some _ ->
        raise Not_found
    | None ->
        itineraries
  in
  Lwt.return itineraries


let edit {Request_data.name; departure; favorite} id =
  get id >>= fun itinerary ->
  let itinerary = match name with
    | None -> itinerary
    | Some name -> {itinerary with Result_data.name = Some name} (* TODO *)
  in
  let itinerary = match departure with
    | None ->
        itinerary
    | Some departure ->
        begin match itinerary.Result_data.destinations with
        | [] -> ()
        | destination::_ -> ItineraryCache.add (departure, destination)
        end;
        {itinerary with Result_data.departure}
  in
  let itinerary = match favorite with
    | None -> itinerary
    | Some favorite -> {itinerary with Result_data.favorite = Some favorite} (* TODO *)
  in
  Db.update_itinerary itinerary >>= fun () ->
  Lwt.return itinerary

let add_destination {Request_data.destination; position} id =
  get id >>= fun itinerary ->
  let destinations = match position with
    | Some position -> Utils.list_insert position destination itinerary.Result_data.destinations
    | None -> itinerary.Result_data.destinations @ [destination]
  in
  let itinerary = {itinerary with Result_data.destinations} in
  recache_itineraries itinerary;
  Db.update_itinerary itinerary >>= fun () ->
  Lwt.return itinerary

let edit_destination {Request_data.Destination_edition.destination; position} ~initial_position id =
  get id >>= fun itinerary ->
  let destinations = match position with
    | Some position ->
        begin match destination with
        | Some destination ->
            let destinations = List.remove_at initial_position itinerary.Result_data.destinations in
            Utils.list_insert position destination destinations
        | None ->
            let (destination, destinations) = Utils.list_take_at initial_position itinerary.Result_data.destinations in
            Utils.list_insert position destination destinations
        end
    | None ->
        List.modify_at initial_position (fun x -> Option.default x destination) itinerary.Result_data.destinations
  in
  let itinerary = {itinerary with Result_data.destinations} in
  recache_itineraries itinerary;
  Db.update_itinerary itinerary >>= fun () ->
  Lwt.return itinerary

let delete_destination ~position id =
  get id >>= fun itinerary ->
  let destinations = List.remove_at position itinerary.Result_data.destinations in
  let itinerary = {itinerary with Result_data.destinations} in
  recache_itineraries itinerary;
  Db.update_itinerary itinerary >>= fun () ->
  Lwt.return itinerary

let delete = Db.delete_itinerary
