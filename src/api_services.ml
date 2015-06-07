module D = Db.Db(Db_macaque)

let (>>=) = Lwt.(>>=)

let json_mime_type = "application/json"

let get_params =
  Eliom_parameter.(suffix (neopt (int "id")))

let path_users = ["users"]

let read_service =
  Eliom_service.Http.service
    ~path:path_users
    ~get_params
    ()

let create_service =
  Eliom_service.Http.post_service
    ~fallback:read_service
    ~post_params:Eliom_parameter.raw_post_data
    ()

let send_json ~code json =
  Eliom_registration.String.send ~code (json, json_mime_type)

let send_error ~code error_message =
  send_json ~code error_message

let send_success () =
  Eliom_registration.String.send ~code:200 ("", "")

let check_content_type ~mime_type content_type =
  match content_type with
  | Some ((type_, subtype), _)
    when (type_ ^ "/" ^ subtype) = mime_type -> true
  | _ -> false

let read_raw_content ?(length = 4096) raw_content =
  let content_stream = Ocsigen_stream.get raw_content in
  Ocsigen_stream.string_of_stream length content_stream

let read_handler id_opt () =
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

let create_handler =
  wrap_body_json
    (fun _ location_str ->
       let open Request_data in
       wrap_errors
         (fun user ->
            D.create_user
              ~username:user.username
              ~password:user.password
              ~email:user.email
            >>= fun _ -> send_success ()
         )
         (user_creation_of_yojson (Yojson.Safe.from_string location_str))
    )

let _ = Eliom_registration.Any.register read_service read_handler

let _ = Eliom_registration.Any.register create_service create_handler

open Eliom_parameter

let () =
  let post_handler get post =
    match get with
    | [] ->
        let aux post =
          wrap_errors
            (fun coords ->
               let itinerary = Itinerary.create coords in
               send_json
                 ~code:200
                 (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
            )
            (Request_data.itinerary_creation_of_yojson (Yojson.Safe.from_string post))
        in
        wrap_body_json (fun () -> aux) () post
    | _ ->
        Eliom_registration.String.send ~code:404 ("", "")
  in
  let get_handler get () =
    match get with
    | [id; "coordinates"; zoom] ->
        let id = int_of_string id in
        let zoom = int_of_string zoom in
        let zoom = Itinerary.Zoomlevel.create zoom in
        let coords = Itinerary.get_coordinates ~zoom id in
        send_json ~code:200 (Yojson.Safe.to_string (Itinerary.coordinate_list_to_yojson coords))
    | [id; "tiles"; z; x; y] ->
        let id = int_of_string id in
        let z = int_of_string z in
        let x = int_of_string x in
        let y = int_of_string y in
        let z = Itinerary.Zoomlevel.create z in
        let image = Itinerary.get_image ~x ~y ~z id in
        Eliom_registration.String.send (image, "image/png")
    | [id] ->
        let id = int_of_string id in
        let itinerary = Itinerary.get id in
        send_json ~code:200 (Yojson.Safe.to_string (Result_data.itinerary_to_yojson itinerary))
    | _ ->
        Eliom_registration.String.send ~code:404 ("", "")
  in
  let service =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (all_suffix "params"))
      ()
  in
  Eliom_registration.Any.register ~service get_handler;
  let service =
    Eliom_service.Http.post_service
      ~fallback:service
      ~post_params:raw_post_data
      ()
  in
  Eliom_registration.Any.register ~service post_handler
