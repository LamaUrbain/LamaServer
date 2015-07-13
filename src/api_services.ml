module D = Db.Db(Db_macaque)
open Request_data

let (>>=) = Lwt.(>>=)

let json_mime_type = "application/json"

let send_json ~code json =
  Eliom_registration.String.send ~code (json, json_mime_type)

let send_error ~code error_message =
  send_json ~code error_message

let send_success ?(content_type = "") ?(content = "") () =
  Eliom_registration.String.send ~code:200 (content, content_type)

let check_content_type ~mime_type content_type =
  match content_type with
  | Some ((type_, subtype), _)
    when (type_ ^ "/" ^ subtype) = mime_type -> true
  | _ -> false

let read_raw_content ?(length = 4096) raw_content =
  let content_stream = Ocsigen_stream.get raw_content in
  Ocsigen_stream.string_of_stream length content_stream

let user_get_handler id_opt () =
  match id_opt with
  | None ->
    send_error ~code:404 "Missing id"
  | Some id ->
    (
      D.find_user id
      >>= function
      | Some u ->
        send_json
          ~code:200
          (Yojson.Safe.to_string (Users.to_yojson u))
      | _ ->
        send_error
          ~code:404
          ("User not found")
    )

let wrap_body_json f get (content_type, raw_content_opt) =
  if not (check_content_type ~mime_type:json_mime_type content_type) then
    send_error ~code:400 "Content-type is wrong, it must be JSON"
  else
    match raw_content_opt with
    | None ->
        send_error ~code:400 "Body content is missing"
    | Some raw_content ->
        read_raw_content raw_content >>= f get

let wrap_errors f = function
  | `Ok x -> f x
  | `Error x -> send_error ~code:400 ("Provided JSON is not valid: " ^ x)

let user_post_handler _ (username ,(password, email))  =
    let user = {username; password;email} in
       wrap_errors
         (fun user ->
            D.create_user
              ~username:user.username
              ~password:user.password
              ~email:user.email
            >>= fun u -> send_success ~content:(Yojson.Safe.to_string (Users.to_yojson u)) ()
         ) (`Ok user)

open Eliom_parameter

let coord_of_param loc =
   let rex = Pcre.regexp "^([-+]?\\d{1,2}([.]\\d+)?),\\s*([-+]?\\d{1,3}([.]\\d+)?)$" in
    let latlong = match Pcre.pmatch ~rex loc with
    | true -> Pcre.split ~rex:(Pcre.regexp ",") loc
    | false -> assert false in
    let (lat, long) = float_of_string (List.nth latlong 0), float_of_string (List.nth latlong 1) in
    {latitude = lat; longitude = long; address = None}


let () =

  let dummy_handler _ _ = Eliom_registration.String.send ~code:201 ("", "") in

  let itinerary_post_handler _ (departure, (favorite, (destination, name))) =
    let destination = BatOption.map coord_of_param destination in
    let departure = coord_of_param departure in
    let coords : Request_data.itinerary_creation = {destination; departure; favorite; name} in
      wrap_errors
        (fun coords ->
         let itinerary = Itinerary.create coords in
         send_json
           ~code:200
           (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
        )
    (`Ok coords)
  in

  let itinerary_get_handler id () =
    let itinerary = Itinerary.get id in
    send_json ~code:200 (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
  in

  let itinerary_put_handler (id, (departure, (favorite, name))) _ =
    let departure = BatOption.map coord_of_param departure in
    let coords : Request_data.itinerary_edition = {departure; favorite; name} in
    wrap_errors
      (fun coords ->
         let itinerary = Itinerary.edit coords id in
         send_json
           ~code:200
           (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
      )
      (`Ok coords)
  in

  let destinations_post_handler (id, ()) (destination, position) =
    let destination = coord_of_param destination in
    let request = {destination; position} in
    wrap_errors
      (fun destination ->
       let itinerary = Itinerary.add_destination destination id in
       send_json
         ~code:200
         (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
      )
      (`Ok request) in

  let destinations_put_handler ((id, ((), pos)), (destination, position)) _ =
    let edit : Request_data.Destination_edition.t =
      {destination = BatOption.map coord_of_param destination; position}
    in
    wrap_errors
      (fun put ->
        let itinerary = Itinerary.edit_destination put ~initial_position:pos id in
        send_json
         ~code:200
         (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
    )
    (`Ok edit)
  in

  let delete_handler get delete =
    match get with
    | [id; "destinations"; position] ->
        let id = int_of_string id in
        let position = int_of_string position in
        let itinerary = Itinerary.delete_destination ~position id in
        send_json
          ~code:200
          (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
    | [id] ->
        let id = int_of_string id in
        Itinerary.delete id;
        Eliom_registration.String.send ~code:200 ("", "")
    | _ ->
        Eliom_registration.String.send ~code:404 ("", "")
  in

  let tiles_get_handler (id, ((), (z, (x, y)))) _ =
    let z = Itinerary.Zoomlevel.create z in
    let image = Itinerary.get_image ~x ~y ~z id in
    Eliom_registration.String.send (image, "image/png") in

  let coords_get_handler (id, ((), z)) _ =
    let zoom = Itinerary.Zoomlevel.create z in
    let coords = Itinerary.get_coordinates ~zoom id in
    send_json ~code:200 (Yojson.Safe.to_string (Itinerary.coordinate_list_to_yojson coords))
  in

  let get_handler_with_params (search, (owner, (favorite, ordering))) () =
    let params =
      { Request_data.search
      ; owner
      ; favorite
      ; ordering
      }
    in
    let itineraries = Itinerary.get_all params in
    send_json ~code:200 (Yojson.Safe.to_string (Itinerary.itineraries_to_yojson itineraries))
  in

  let service =
    Eliom_service.Http.delete_service
      ~path:["itineraries"]
      ~get_params:(suffix (all_suffix "params"))
      ()
  in
  Eliom_registration.Any.register ~service delete_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int "id"))
      ()
  in
  Eliom_registration.Any.register ~service itinerary_get_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries";""]
      ~get_params:(opt (string "search")
                   ** opt (string "owner")
                   ** opt (bool "favorite")
                   ** opt (string "ordering"))
      ()
  in
  Eliom_registration.Any.register ~service get_handler_with_params;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "departure"
                    ** opt (bool "favorite")
                    ** opt (string "destination")
                    ** opt (string "name"))
     ()
  in
  Eliom_registration.Any.register ~service itinerary_post_handler;

  let service =
    Eliom_service.Http.put_service
      ~path:["itineraries"]
      ~get_params:(suffix_prod
                     (int "id")
                     (opt (string "departure")
                      ** opt (bool "favorite")
                      ** opt (string "name")
                     )
                  )
      ()
  in
  Eliom_registration.Any.register ~service itinerary_put_handler;

  (* dummy get service *)
  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int "id" ** suffix_const "destinations"))
      () in
  Eliom_registration.Any.register ~service dummy_handler;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "destination"
                    ** opt (int "position"))
     ()
  in
  Eliom_registration.Any.register ~service destinations_post_handler;
  let service =
    Eliom_service.Http.put_service
      ~path:["itineraries"]
      ~get_params:(suffix_prod
                     (int "id" ** suffix_const "destinations" ** int "pos")
                     (opt (string "destination") ** opt (int "position"))
                  )
      ()
  in
  Eliom_registration.Any.register ~service destinations_put_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (
                   int "id" **
                   suffix_const "tiles" **
                   int "z" **
                   int "x" **
                   int "y")
      )
      ()
  in
  Eliom_registration.Any.register ~service tiles_get_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (
                   int "id" **
                   suffix_const "coordinates" **
                   int "z"))
      () in
  Eliom_registration.Any.register ~service coords_get_handler;

  let service =
    Eliom_service.Http.service
      ~path:["users"]
      ~get_params:(suffix (neopt (int "id")))
      () in
  Eliom_registration.Any.register ~service user_get_handler;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "username"
                    ** (string "password")
                    ** (string "email"))
      ()
  in
  Eliom_registration.Any.register ~service user_post_handler;
