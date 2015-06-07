type t = int

type coordinate = {x : int; y : int} [@@deriving yojson]
type coordinate_list = coordinate list [@@deriving yojson]

module Zoomlevel : sig
  type t

  val create : int -> t
end

val create : Request_data.itinerary_creation -> Result_data.itinerary

val get_coordinates : zoom:Zoomlevel.t -> t -> coordinate_list

val get_image : x:int -> y:int -> z:Zoomlevel.t -> t -> string

val get : t -> Result_data.itinerary

val edit : Request_data.itinerary_edition -> t -> Result_data.itinerary

val add_destination : Request_data.add_destination -> t -> Result_data.itinerary
