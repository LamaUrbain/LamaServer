module type DBENGINE =
sig
  val create_user : username:string -> password:string -> email:string -> Users.t Lwt.t
  val find_user : int -> Users.t option Lwt.t
end

module Db =
  functor (M : DBENGINE) ->
  struct
    let create_user = M.create_user
    let find_user = M.find_user
  end
