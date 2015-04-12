type t = int

type coordinate = {x : int; y : int}

module Zoomlevel : sig
  type t

  val create : int -> t
end

val create : starting_point:(float * float) -> ending_point:(float * float) -> t

val get_coordinates : zoom:Zoomlevel.t -> t -> coordinate list

val get_image : x:int -> y:int -> z:int -> t -> string
