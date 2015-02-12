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
    send_error ~code:404 "lol"
  | Some id ->
      (
        match Db_mongodb.find_user id with
        | Some u ->
        send_json
          ~code:200
          u.Users.username
        | _ ->
          send_error
            ~code:404
            ("User not found")
      )

let edit_handler_aux ?(create = false) (id_opt : int option) (content_type, raw_content_opt) =
  if not (check_content_type ~mime_type:json_mime_type content_type) then
    send_error ~code:400 "Content-type is wrong, it must be JSON"
  else
    match id_opt, raw_content_opt with
    | _, None ->
      send_error ~code:400 "Body content is missing"
    | Some id, Some raw_content ->
      read_raw_content raw_content >>= fun location_str ->
      Lwt.catch (fun () ->
          (if create then
            let user = Yojson.from_string<Users.t> location_str in
            Db_mongodb.create_user ~user;
            send_success ()
           else
            send_success ()))
    (*         Ocsipersist.find db id >>= fun _ -> Lwt.return_unit)

          >>= fun () ->
          let location = Yojson.from_string<location> location_str in
          Ocsipersist.add db id location >>= fun () ->
          send_success ()) *)

        (function
          | Not_found ->
            send_error ~code:404 ("Location not found: " ^ "lol")
          | Deriving_Yojson.Failed ->
            send_error ~code:400 "Provided JSON is not valid")

let create_handler id_opt content =
    edit_handler_aux ~create:true id_opt content

let _ = Eliom_registration.Any.register read_service read_handler

let _ = Eliom_registration.Any.register create_service create_handler
