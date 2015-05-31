open BatteriesExceptionless
open Monomorphic

type t =
  { map : string option
  ; style : string option
  ; host : string option
  ; database : string option
  ; user : string option
  ; password : string option
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
             | ("host", host) -> {data with host = Some host}
             | ("database", database) -> {data with database = Some database}
             | ("user", user) -> {data with user = Some user}
             | ("password-file", password_file) ->
                 let password = File.with_file_in password_file IO.read_all in
                 {data with password = Some password}
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

let {map; style; host; database; user; password} =
  let data =
    { map = None
    ; style = None
    ; host = None
    ; database = None
    ; user = None
    ; password = None
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

let host =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"database" "host")
    host

let database =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"database" "database")
    database

let user =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"database" "user")
    user

let password =
  Option.default_delayed
    (fun () -> Configfile.fail_missing ~tag:"database" "password")
    password
