val create_user : username:string -> password:string -> email:string -> Users.t Lwt.t
val find_user : int -> Users.t option Lwt.t
val find_user_username : string -> Users.t option Lwt.t
val create_session : user:Users.t -> Sessions.t Lwt.t
val find_session : string -> Sessions.t option Lwt.t
