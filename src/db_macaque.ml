open Batteries
open Eliom_lib.Lwt_ops

module Db = Db_macaque_wrapper

let users_id_seq = (<:sequence< serial "users_id_seq" >>)

let users_table =
  (<:table< users_table (
    username text NOT NULL,
    password text NOT NULL,
    email text NOT NULL,
    id integer NOT NULL DEFAULT(nextval $users_id_seq$)
   ) >>)

let create_user ~username ~password ~email =
  Db.value (<:value< $users_table$?id >>)
  >>= fun id ->
  Db.query
    <:insert< $users_table$ :=
                 {
                 username = $string:username$;
                 password = $string:password$;
                 email = $string:email$;
                 id = $int32:id$;
                 } >>
  >>= fun () ->
  Lwt.return
    Users.({
        username;
        password;
        email;
        id = Int32.to_int id;
      })

let to_user =
  let open Users in
  let f x =
    {
    username = x#!username;
    password = x#!password;
    email = x#!email;
    id = Int32.to_int x#!id;
    }
  in
  Option.map f

let find_user id =
  let id = Int32.of_int id in
  Db.view_opt
    <:view< {
            username = user_.username;
            password = user_.password;
            email = user_.email;
            id = user_.id;
            } |
            user_ in $users_table$;
            user_.id = $int32:id$; >>
    >|= to_user
