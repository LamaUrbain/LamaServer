module type DBENGINE =
sig
  val create_user : user:Users.t -> Users.t
  val find_user : int -> Users.t option
end

module Db =
  functor (M : DBENGINE) ->
  struct
    let create_user ~user = M.create_user user
    let find_user id = M.find_user id
  end
