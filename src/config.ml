open BatteriesExceptionless
open Monomorphic

(** Public types *)

type postgres =
  { host : string
  ; port : int option
  ; database : string
  ; user : string
  ; password : string
  }

type mongodb =
  { host : string
  ; port : int
  ; name : string
  }

type database =
  | Postgres of postgres
  | MongoDB of mongodb

(** Internal types *)

type t =
  { map : string option
  ; style : string option
  ; database_type : string option
  ; database_host : string option
  ; database_name : string option
  ; database_user : string option
  ; database_password : string option
  ; database_port : int option
  }

let rec init_fun data = function
  | Simplexmlparser.Element ("config" as tag, attribs, [])::l ->
      let data =
        List.fold_left
          (fun data -> function
             | ("map", map) -> {data with map = Some map}
             | ("style", style) -> {data with style = Some style}
             | (x, _) -> Configfile.fail_attrib ~tag x
          )
          data
          attribs
      in
      init_fun data l
  | Simplexmlparser.Element ("database" as tag, attribs, [])::l ->
      let data =
        List.fold_left
          (fun data -> function
             | ("type", typ) -> {data with database_type = Some typ}
             | ("host", host) -> {data with database_host = Some host}
             | ("database-name", name) -> {data with database_name = Some name}
             | ("user", user) -> {data with database_user = Some user}
             | ("password-file", password_file) ->
                 let password = File.with_file_in password_file IO.read_all in
                 {data with database_password = Some password}
             | ("port", port) ->
                 {data with database_port = Some (int_of_string port)}
             | (x, _) -> Configfile.fail_attrib ~tag x
          )
          data
          attribs
      in
      init_fun data l
  | Simplexmlparser.Element (tag, _, _)::_ ->
      Configfile.fail_tag ~tag
  | Simplexmlparser.PCData pcdata :: _ ->
      Configfile.fail_pcdata pcdata
  | [] ->
      data

let { map
    ; style
    ; database_type
    ; database_host
    ; database_name
    ; database_user
    ; database_password
    ; database_port
    } =
  let data =
    { map = None
    ; style = None
    ; database_type = None
    ; database_host = None
    ; database_name = None
    ; database_user = None
    ; database_password = None
    ; database_port = None
    }
  in
  let c = Eliom_config.get_config () in
  init_fun data c

let map =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"config" "map")
    map

let style =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"config" "style")
    style

let database =
  let typ =
    Option.default_delayed
      (fun () -> Configfile.fail_tag ~tag:"database")
      database_type
  in
  let host =
    Option.default_delayed
      (fun () -> Configfile.fail_missing ~tag:"database" "host")
      database_host
  in
  let name =
    Option.default_delayed
      (fun () -> Configfile.fail_missing ~tag:"database" "name")
      database_name
  in
  match typ with
  | "postgres" ->
      let password =
        Option.default_delayed
          (fun () -> Configfile.fail_missing ~tag:"database" "password-file")
          database_password
      in
      let user =
        Option.default_delayed
          (fun () -> Configfile.fail_missing ~tag:"database" "user")
          database_user
      in
      Postgres {host; port = database_port; database = name; user; password}
  | "mongo" ->
      let port =
        Option.default_delayed
          (fun () -> Configfile.fail_missing ~tag:"database" "port")
          database_port
      in
      MongoDB {host; port; name}
  | _ ->
      raise
        (Ocsigen_extensions.Error_in_config_file "Database type not recognize")
