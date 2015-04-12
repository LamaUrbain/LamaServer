type t = int

type coordinate = {x : int; y : int} deriving (Yojson)

module Zoomlevel : sig
  type t

  val create : int -> t
end

val create : Request_data.itinerary_creation -> t

val get_coordinates : zoom:Zoomlevel.t -> t -> coordinate list

val get_image : x:int -> y:int -> z:Zoomlevel.t -> t -> string
