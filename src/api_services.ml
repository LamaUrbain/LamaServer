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

let create_handler _ (content_type, raw_content_opt) =
  if not (check_content_type ~mime_type:json_mime_type content_type) then
    send_error ~code:400 "Content-type is wrong, it must be JSON"
  else
    match raw_content_opt with
    | None ->
      send_error ~code:400 "Body content is missing"
    | Some raw_content ->
      read_raw_content raw_content
      >>= fun location_str ->
      Lwt.catch
        (fun () ->
           let open Request_data in
           let user = Yojson.from_string<user_creation> location_str in
           D.create_user
             ~username:user.username
             ~password:user.password
             ~email:user.email
           >>= fun _ -> send_success ())
        (function
          | Deriving_Yojson.Failed ->
            send_error ~code:400 "Provided JSON is not valid"
        )

let _ = Eliom_registration.Any.register read_service read_handler

let _ = Eliom_registration.Any.register create_service create_handler
