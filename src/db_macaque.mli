val create_user : username:string -> password:string -> email:string -> sponsor:bool -> Users.t Lwt.t
val find_user : int -> Users.t option Lwt.t
val find_user_username : string -> Users.t option Lwt.t
val delete_user : string -> unit Lwt.t
val get_all_users : unit -> Users.t list Lwt.t
val get_sponsored_users : bool -> Users.t list Lwt.t
val search_user : string -> Users.t list Lwt.t
val edit_user : id:string -> username:string option -> password:string option -> email:string option -> sponsor:bool option -> unit Lwt.t

val create_session : user:Users.t -> Sessions.t Lwt.t
val find_session : string -> Sessions.t option Lwt.t
val delete_session : string -> unit Lwt.t

val create_itinerary :
  owner:string option ->
  name:string option ->
  favorite:bool option ->
  departure:Request_data.coord ->
  destinations:Request_data.coord list ->
  vehicle:int32 ->
  Result_data.itinerary option Lwt.t
val update_itinerary : Result_data.itinerary -> unit Lwt.t
val delete_itinerary : int32 -> unit Lwt.t
val get_itinerary : int32 -> Result_data.itinerary option Lwt.t
val get_all_itineraries : unit -> Result_data.itinerary list Lwt.t

val create_incident :
  name:string ->
  end_:Calendar.t option ->
  position:Request_data.coord ->
  Incident.t option Lwt.t
val delete_incident : int32 -> unit Lwt.t
val get_incident : int32 -> Incident.t option Lwt.t
val get_all_incidents : unit -> Incident.t list Lwt.t
