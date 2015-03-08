val view : ('a, 'b) Sql.view -> 'a list Lwt.t

val view_one : ('a, 'b) Sql.view -> 'a Lwt.t

val view_opt : ('a, 'b) Sql.view -> 'a option Lwt.t

val query : unit Sql.query -> unit Lwt.t

val value :
  < nul : Sql.non_nullable; t : 'a #Sql.type_info; .. > Sql.t ->
  'a Lwt.t

val value_opt :
  < nul : Sql.nullable; t : 'a #Sql.type_info; .. > Sql.t ->
  'a option Lwt.t

val alter : string -> unit Lwt.t
