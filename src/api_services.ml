module D = Db.Db(Db_macaque)
open Request_data
open BatteriesExceptionless

type ('a, 'b) error = Error of 'a | Answer of 'b

let (>>=) = Lwt.(>>=)

let (|>>) v f = v >>= fun value ->
  match value with
  | Some value -> f value
  | None -> Lwt.fail_with "Error while unwrapping"

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

let user_get_handler (id_opt, (search_pattern, sponsored)) () =
  match id_opt, sponsored with
  | None, None ->
     begin
       match search_pattern with
       | None ->
	  D.get_all_users ()
	  >>= fun users ->
	  send_json
	    ~code:200
	    (Yojson.Safe.to_string (Users.users_to_yojson users))
       | Some pattern ->
	    D.search_user pattern
	    >>= fun users ->
	    send_json
	      ~code:200
	      (Yojson.Safe.to_string (Users.users_to_yojson users))
     end
  | _, Some is_sponsor ->
     D.get_sponsored_users is_sponsor
     >>= fun users ->
     send_json
       ~code:200
       (Yojson.Safe.to_string (Users.users_to_yojson users))
  | Some id, _ ->
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

let get_token_user t =
  Option.map_default
    (fun token ->D.find_session token >>= (fun s -> Lwt.return @@ Option.map (fun x -> x.Sessions.owner) s))
    (Lwt.return None) t

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

let user_post_handler _ (username ,(password, (email, sponsor)))  =
    let user = {username;password;email} in
       wrap_errors
         (fun user ->
            D.create_user
              ~username:user.username
              ~password:user.password
              ~email:user.email
	      ~sponsor:sponsor
            >>= fun u -> send_success ~content:(Yojson.Safe.to_string (Users.to_yojson u)) ()
         ) (`Ok user)

let session_post_handler _ (username, password)  =
  D.find_user_username username >>= fun u ->
  match u with
    | Some user_t when user_t.password <> password ->
       send_error
	 ~code:400
	 ("Password don't match")
    | Some user_t ->
       wrap_errors
         (fun user ->
            D.create_session ~user
            >>= fun s -> send_success ~content:(Yojson.Safe.to_string (Sessions.to_yojson s)) ()
         ) (`Ok user_t)
    | otherwise ->
        send_error
          ~code:404
          ("User not found")

let session_get_handler token_opt () =
  match token_opt with
  | None ->
    send_error ~code:404 "Missing id"
  | Some token ->
    (
      D.find_session token
      >>= function
      | Some s ->
        send_json
          ~code:200
          (Yojson.Safe.to_string (Sessions.to_yojson s))
      | _ ->
        send_error
          ~code:404
          ("User not found")
    )

let users_delete_handler (id, token) _ =
  D.find_user_username id >>= fun u ->
  match u with
    | Some user_t ->
       wrap_errors
         (fun user ->
	  D.delete_user id
	    >>= fun s -> send_success ~content:"" ()
         ) (`Ok user_t)
    | otherwise ->
        send_error
          ~code:404
          ("User not found")

let sessions_delete_handler token _ =
  wrap_errors
    (fun _ ->
     D.delete_session token
     >>= fun s -> send_success ~content:"" ()
    ) (`Ok ())

    let check_itinerary_ownership itinerary token =
    D.get_itinerary itinerary >>= fun i ->
    match i with
    | Some itinerary ->
    begin
      if BatOption.default false itinerary.favorite then
      (
        match token with
        | Some t -> (
          D.find_session t >>= fun s ->
          match s with
          | Some session -> if BatOption.is_none @@ BatOption.map ((=) session.owner) itinerary.owner
          then Lwt.return(Answer(itinerary))
        else Lwt.return(Error("User not allowed to edit this itinerary"))
        | None -> Lwt.return(Error("Invalid Session"))
      )
        | None -> Lwt.return(Error("No token provided"))
      )
    else Lwt.return(Answer(itinerary))
  end
  | None -> Lwt.return(Error("Itinerary not found"))

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

  let itinerary_post_handler _ (departure, (favorite, (destination, (name, token)))) =
    let destination = BatOption.map coord_of_param destination in
    let departure = coord_of_param departure in
    let coords : Request_data.itinerary_creation = {destination; departure; favorite; name} in
      wrap_errors
        (fun coords ->
	 get_token_user token >>= (fun owner ->
         Itinerary.create coords ?owner |>> fun itinerary ->
         send_json
           ~code:200
           (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
        ))
    (`Ok coords)
  in

  let itinerary_get_handler id () =
    Itinerary.get id >>= fun itinerary ->
    send_json ~code:200 (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
  in

  let itinerary_put_handler (id, (departure, (favorite, (name, token)))) _ =
    check_itinerary_ownership id token >>= fun it ->
    match it with
    | Answer _ -> (
      let departure = BatOption.map coord_of_param departure in
      let coords : Request_data.itinerary_edition = {departure; favorite; name} in
      wrap_errors
      (fun coords ->
       Itinerary.edit coords id >>= fun itinerary ->
       send_json
       ~code:200
       (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
      )
      (`Ok coords)
    )
    | Error e -> send_error ~code:403 e
  in

  let destinations_post_handler (id, ()) (destination, (position, token)) =
    check_itinerary_ownership id token >>= fun it ->
    match it with
    | Answer _ -> (
    let destination = coord_of_param destination in
    let request = {destination; position} in
    wrap_errors
      (fun destination ->
       Itinerary.add_destination destination id >>= fun itinerary ->
       send_json
         ~code:200
         (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
      )
      (`Ok request)
      )
    | Error e -> send_error ~code:403 e
  in

  let destinations_put_handler ((id, ((), pos)), (destination, (position, token))) _ =
    check_itinerary_ownership id token >>= fun it ->
    match it with
    | Answer _ -> (
    let edit : Request_data.Destination_edition.t =
      {destination = BatOption.map coord_of_param destination; position}
    in
    wrap_errors
      (fun put ->
        Itinerary.edit_destination put ~initial_position:pos id >>= fun itinerary ->
        send_json
         ~code:200
         (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
    )
    (`Ok edit)
  )
    | Error e -> send_error ~code:403 e
  in

  let delete_handler (get, token) delete  =
    match get with
    | [id; "destinations"; position] ->
        let id = Int32.of_string id in
        let position = int_of_string position in
        Itinerary.delete_destination ~position id >>= fun itinerary ->
        send_json
          ~code:200
          (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
    | [id] ->
        let id = Int32.of_string id in
        Itinerary.delete id >>= fun () ->
        Eliom_registration.String.send ~code:200 ("", "")
    | _ ->
        Eliom_registration.String.send ~code:404 ("", "")
  in

  let tiles_get_handler (id, ((), (z, (x, y)))) _ =
    let z = Itinerary.Zoomlevel.create z in
    Itinerary.get_image ~x ~y ~z id >>= fun image ->
    Eliom_registration.String.send (image, "image/png") in

  let coords_get_handler (id, ((), z)) _ =
    let zoom = Itinerary.Zoomlevel.create z in
    Itinerary.get_coordinates ~zoom id >>= fun coords ->
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
    Itinerary.get_all params >>= fun itineraries ->
    send_json ~code:200 (Yojson.Safe.to_string (Itinerary.itineraries_to_yojson itineraries))
  in

  let service =
    Eliom_service.Http.delete_service
      ~path:["itineraries"]
      ~get_params:(suffix_prod (all_suffix "params") (opt (string "token")))
      ()
  in
  Eliom_registration.Any.register ~service delete_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int32 "id"))
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
                    ** opt (string "name")
                    ** opt (string "token")
		   )
     ()
  in
  Eliom_registration.Any.register ~service itinerary_post_handler;

  let service =
    Eliom_service.Http.put_service
      ~path:["itineraries"]
      ~get_params:(suffix_prod
                     (int32 "id")
                     (opt (string "departure")
                      ** opt (bool "favorite")
                      ** opt (string "name")
                      ** opt (string "token")
                     )
                  )
      ()
  in
  Eliom_registration.Any.register ~service itinerary_put_handler;

  (* dummy get service *)
  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int32 "id" ** suffix_const "destinations"))
      () in
  Eliom_registration.Any.register ~service dummy_handler;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "destination"
                    ** opt (int "position")
                    ** opt (string "token")
                  )
     ()
  in
  Eliom_registration.Any.register ~service destinations_post_handler;
  let service =
    Eliom_service.Http.put_service
      ~path:["itineraries"]
      ~get_params:(suffix_prod
                     (int32 "id" ** suffix_const "destinations" ** int "pos")
                     (opt (string "destination") ** opt (int "position") ** opt (string "token"))
                  )
      ()
  in
  Eliom_registration.Any.register ~service destinations_put_handler;

  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (
                   int32 "id" **
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
                   int32 "id" **
                   suffix_const "coordinates" **
                   int "z"))
      () in
  Eliom_registration.Any.register ~service coords_get_handler;

  let service =
    Eliom_service.Http.service
      ~path:["users"]
      ~get_params:(suffix_prod (neopt (int "id")) (opt (string "search") ** opt (bool "sponsored")))
      () in
  Eliom_registration.Any.register ~service user_get_handler;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "username"
                    ** (string "password")
                    ** (string "email")
		    ** (bool "sponsor"))
      ()
  in
  Eliom_registration.Any.register ~service user_post_handler;

  let service =
    Eliom_service.Http.service
      ~path:["sessions"]
      ~get_params:(suffix (neopt (string "token")))
      () in
  Eliom_registration.Any.register ~service session_get_handler;

  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:(string "username"
                    ** (string "password"))
      ()
  in
  Eliom_registration.Any.register ~service session_post_handler;

  let service =
    Eliom_service.Http.delete_service
      ~path:["users"]
      ~get_params:(suffix_prod (string "id") (string "token"))
      ()
  in
  Eliom_registration.Any.register ~service users_delete_handler;

  let service =
    Eliom_service.Http.delete_service
      ~path:["sessions"]
      ~get_params:(suffix (string "token"))
      ()
  in
  Eliom_registration.Any.register ~service sessions_delete_handler;
