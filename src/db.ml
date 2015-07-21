module type DBENGINE =
sig
  val create_user : username:string -> password:string -> email:string -> Users.t Lwt.t
  val find_user : int -> Users.t option Lwt.t
  val find_user_username : string -> Users.t option Lwt.t
  val delete_user : int -> unit Lwt.t
  val create_session : user:Users.t -> Sessions.t Lwt.t
  val find_session : string -> Sessions.t option Lwt.t
  val delete_session : string -> unit Lwt.t
end

module Db =
  functor (M : DBENGINE) ->
  struct
    let create_user = M.create_user
    let find_user = M.find_user
    let find_user_username = M.find_user_username
    let delete_user = M.delete_user
    let create_session = M.create_session
    let find_session = M.find_session
    let delete_session = M.delete_session
 end
