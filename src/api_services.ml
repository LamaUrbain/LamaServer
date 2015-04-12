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
          (Yojson.to_string<Users.t> u)
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
        read_raw_content raw_content >>= fun location_str ->
        Lwt.catch
          (fun () -> f get location_str)
          (function
            | Deriving_Yojson.Failed ->
                send_error ~code:400 "Provided JSON is not valid"
          )

let create_handler =
  wrap_body_json
    (fun _ location_str ->
       let open Request_data in
       let user = Yojson.from_string<user_creation> location_str in
       D.create_user
         ~username:user.username
         ~password:user.password
         ~email:user.email
       >>= fun _ -> send_success ()
    )

let _ = Eliom_registration.Any.register read_service read_handler

let _ = Eliom_registration.Any.register create_service create_handler

open Eliom_parameter

let () =
  let aux () location_str =
    let open Request_data in
    let coords = Yojson.from_string<itinerary_creation> location_str in
    let id = Itinerary.create coords in
    send_json ~code:200 (Yojson.to_string<id> {id})
  in
  let fallback =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:unit
      ()
  in
  let service =
    Eliom_service.Http.post_service
      ~fallback
      ~post_params:raw_post_data
      ()
  in
  Eliom_registration.Any.register ~service (wrap_body_json aux)

let () =
  let aux (id, (_, zoom)) () =
    let zoom = Itinerary.Zoomlevel.create zoom in
    let coords = Itinerary.get_coordinates ~zoom id in
    send_json ~code:200 (Yojson.to_string<Itinerary.coordinate list> coords)
  in
  let fallback =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int "id" ** regexp (Netstring_pcre.regexp "coordinates") "" ~to_string:(fun x -> x) "const" ** int "zoomlevel"))
      ()
  in
  let service =
    Eliom_service.Http.post_service
      ~fallback
      ~post_params:unit
      ()
  in
  Eliom_registration.Any.register ~service aux

let () =
  let aux (id, (_, (z, (x, y)))) () =
    let z = Itinerary.Zoomlevel.create z in
    let image = Itinerary.get_image ~x ~y ~z id in
    Lwt.return (image, "image/png")
  in
  let fallback =
    Eliom_service.Http.service
      ~path:["itineraries"]
      ~get_params:(suffix (int "id" ** regexp (Netstring_pcre.regexp "tiles") "" ~to_string:(fun x -> x) "const" ** int "zoomlevel" ** int "x" ** int "y"))
      ()
  in
  let service =
    Eliom_service.Http.post_service
      ~fallback
      ~post_params:unit
      ()
  in
  Eliom_registration.String.register ~service aux
