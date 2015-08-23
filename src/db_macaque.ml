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

let itineraries_id_seq = (<:sequence< serial "itineraries_id_seq" >>)

let itineraries_table =
  (<:table< itineraries_table (
    id integer NOT NULL DEFAULT(nextval $itineraries_id_seq$),
    owner text,
    name text,
    creation timestamp NOT NULL DEFAULT(localtimestamp ()),
    favorite boolean,
    departure integer NOT NULL,
    destinations int32_array NOT NULL
   ) >>)

let coords_id_seq = (<:sequence< serial "coords_id_seq" >>)

let coords_table =
  (<:table< coords_table (
    id integer NOT NULL DEFAULT(nextval $coords_id_seq$),
    address text,
    latitude double NOT NULL,
    longitude double NOT NULL
  ) >>)

let to_coord coord =
  { Request_data.address = coord#?address
  ; latitude = coord#!latitude
  ; longitude = coord#!longitude
  }

let to_itinerary itinerary =
  Db.view_one (<:view< t | t in $coords_table$; t.id = $itinerary#departure$ >>)
  >|= to_coord >>= fun departure ->
  let aux id =
    let id = Option.default_delayed (fun () -> assert false) id in
    Db.view_one (<:view< t | t in $coords_table$; t.id = $int32:id$ >>)
    >|= to_coord
  in
  Lwt_list.map_s aux itinerary#!destinations
  >|= fun destinations ->
  { Result_data.id = itinerary#!id
  ; owner = itinerary#?owner
  ; name = itinerary#?name
  ; creation = CalendarLib.Printer.Calendar.sprint "%iT%TZ" itinerary#!creation
  ; favorite = itinerary#?favorite
  ; departure
  ; destinations
  }

let get_itinerary id =
  Db.view_one (<:view< t | t in $itineraries_table$; t.id = $int32:id$ >>)
  >>= to_itinerary >>= fun s -> Lwt.return(Some(s))

let create_coord coord =
  Db.value (<:value< $coords_table$?id >>) >>= fun id ->
  Db.query
    (<:insert< $coords_table$ := {
      id = $int32:id$;
      address = of_option $Option.map Sql.Value.string coord.Request_data.address$;
      latitude = $float:coord.Request_data.latitude$;
      longitude = $float:coord.Request_data.longitude$;
    } >>)
  >|= fun () ->
  id

let create_itinerary ~owner ~name ~favorite ~departure ~destinations =
  Db.value (<:value< $itineraries_table$?id >>) >>= fun itinerary_id ->
  create_coord departure >>= fun departure_id ->
  Lwt_list.map_s create_coord destinations >>= fun destinations -> (* TODO: PARALLEL ? *)
  let destinations = List.map Option.some destinations in
  Db.query
    (<:insert< $itineraries_table$ := {
      id = $int32:itinerary_id$;
      owner = of_option $Option.map Sql.Value.string owner$;
      name = of_option $Option.map Sql.Value.string name$;
      creation = $itineraries_table$?creation;
      favorite = of_option $Option.map Sql.Value.bool favorite$;
      departure = $int32:departure_id$;
      destinations = $int32_array:destinations$;
    } >>)
  >>= fun () ->
  get_itinerary itinerary_id

let update_itinerary itinerary =
  create_coord itinerary.Result_data.departure >>= fun departure_id ->
  Lwt_list.map_s create_coord itinerary.Result_data.destinations >>= fun destinations -> (* TODO: PARALLEL ? *)
  let destinations = List.map Option.some destinations in
  Db.query
    (<:update< t in $itineraries_table$ := {
      owner = of_option $Option.map Sql.Value.string itinerary.Result_data.owner$;
      name = of_option $Option.map Sql.Value.string itinerary.Result_data.name$;
      favorite = of_option $Option.map Sql.Value.bool itinerary.Result_data.favorite$;
      departure = $int32:departure_id$;
      destinations = $int32_array:destinations$;
    } | t.id = $int32:itinerary.Result_data.id$ >>)

let delete_itinerary id =
  Db.query (<:delete< t in $itineraries_table$ | t.id = $int32:id$ >>)

let get_all_itineraries () =
  Db.view (<:view< t | t in $itineraries_table$ >>)
  >>= Lwt_list.map_s to_itinerary
