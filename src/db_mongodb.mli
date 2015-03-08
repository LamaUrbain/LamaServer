val create_user : username:string -> password:string -> email:string -> Users.t Lwt.t
val find_user : int -> Users.t option Lwt.t
