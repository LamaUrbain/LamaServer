type t = int

type coordinate = {x : int; y : int} [@@deriving yojson]
type coordinate_list = coordinate list [@@deriving yojson]

type itineraries = Result_data.itinerary list [@@deriving yojson]

module Zoomlevel : sig
  type t

  val create : int -> t
end

val create : Request_data.itinerary_creation -> Result_data.itinerary Lwt.t

val get_coordinates : zoom:Zoomlevel.t -> t -> coordinate_list Lwt.t

val get_image : x:int -> y:int -> z:Zoomlevel.t -> t -> string Lwt.t

val get_all : Request_data.get_all -> itineraries Lwt.t

val get : t -> Result_data.itinerary Lwt.t

val edit : Request_data.itinerary_edition -> t -> Result_data.itinerary Lwt.t

val add_destination : Request_data.destination_addition -> t -> Result_data.itinerary Lwt.t

val edit_destination : Request_data.Destination_edition.t -> initial_position:int -> t -> Result_data.itinerary Lwt.t

val delete_destination : position:int -> t -> Result_data.itinerary Lwt.t

val delete : t -> unit Lwt.t
