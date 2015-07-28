open Batteries
open Eliom_lib.Lwt_ops

module Db = Db_macaque_wrapper

module Calendar = struct
  include CalendarLib.Calendar
  module Printer = CalendarLib.Printer.Calendar
end

let string_of_calendar cal = Calendar.Printer.sprint "%d/%m/%Y à %T" cal

let users_id_seq = (<:sequence< serial "users_id_seq" >>)

let users_table =
  (<:table< users_table (
    username text NOT NULL,
    password text NOT NULL,
    email text NOT NULL,
    created timestamp NOT NULL DEFAULT(localtimestamp ()),
    id integer NOT NULL DEFAULT(nextval $users_id_seq$)
   ) >>)

let auth_table = (<:table< auth_table (
  token text NOT NULL,
  owner text NOT NULL,
  created timestamp NOT NULL DEFAULT(localtimestamp ())
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
                 created = $users_table$?created;
                 id = $int32:id$;
                 } >>
  >>= fun _ ->
  Lwt.return
    Users.({
        username;
        password;
        email;
        created = "";
        id = Int32.to_int id;
      })

let to_user =
  let open Users in
  let f x =
    {
    username = x#!username;
    password = x#!password;
    email = x#!email;
    created = string_of_calendar x#!created;
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
            created = user_.created;
            id = user_.id;
            } |
            user_ in $users_table$;
            user_.id = $int32:id$; >>
    >|= to_user

let find_user_username username =
  Db.view_opt
    <:view< {
            username = user_.username;
            password = user_.password;
            email = user_.email;
            created = user_.created;
            id = user_.id;
            } |
            user_ in $users_table$;
            user_.username = $string:username$; >>
    >|= to_user

let delete_user id =
  Db.query
    (<:delete< _user in $users_table$ | _user.username = $string:id$ >>)

let gen_str length =
  let gen() = match Random.int(26+26+10) with
  n when n < 26 -> int_of_char 'a' + n
                    | n when n < 26 + 26 -> int_of_char 'A' + n - 26
                    | n -> int_of_char '0' + n - 26 - 26 in
  let gen _ = String.make 1 (char_of_int(gen())) in
  String.concat "" (Array.to_list (Array.init length gen));;

let create_session ~user =
  let token = gen_str 32 in
  let owner = user.Users.username in
  Db.query
    <:insert< $auth_table$ :=
     {
     token = $string:token$;
     owner = $string:owner$;
     created = $auth_table$?created;
     } >>
  >>= fun _ ->
  Lwt.return
    Sessions.({
		 token;
		 owner;
		 created = "";
  })

let to_session =
  let open Sessions in
  let f x =
    {
    token = x#!token;
    owner = x#!owner;
    created = string_of_calendar x#!created;
    }
  in
  Option.map f

let find_session token =
  Db.view_opt
    <:view< {
            token = auth_.token;
            owner = auth_.owner;
            created = auth_.created;
            } |
            auth_ in $auth_table$;
            auth_.token = $string:token$; >>
    >|= to_session

let delete_session token =
  Db.query
    (<:delete< _session in $auth_table$ | _session.token = $string:token$ >>)

(*
   let creation =
   CalendarLib.Printer.Calendar.sprint "%iT%TZ" (CalendarLib.Calendar.now ())
   in
*)

let create_itinerary = assert false
let update_itinerary = assert false
let delete_itinerary = assert false
let get_itinerary = assert false
let get_all_itineraries = assert false
