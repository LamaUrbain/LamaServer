module Lwt_thread = struct
  include Lwt
  include Lwt_chan
end
module Lwt_PGOCaml = PGOCaml_generic.Make(Lwt_thread)
module Lwt_Query = Query.Make_with_Db(Lwt_thread)(Lwt_PGOCaml)

let connect =
  match Config.database with
  | Config.Postgres {Config.host; port; database; user; password} ->
      Lwt_PGOCaml.connect
        ~host
        ?port
        ~database
        ~user
        ~password
        ?unix_domain_socket_dir:None
  | Config.MongoDB _ ->
      (fun () -> assert false)

let pool = lazy (Lwt_pool.create 16 ~validate:Lwt_PGOCaml.alive connect)

let use f = Lwt_pool.use (Lazy.force pool) f

(** Debugging *)
let log = Some Pervasives.stderr
(*let log = None*)

let view x = use (fun db -> Lwt_Query.view db ?log x)
let view_opt x = use (fun db -> Lwt_Query.view_opt db ?log x)
let view_one x = use (fun db -> Lwt_Query.view_one db ?log x)
let query x = use (fun db -> Lwt_Query.query db ?log x)
let value x = use (fun db -> Lwt_Query.value db ?log x)
let value_opt x = use (fun db -> Lwt_Query.value_opt db ?log x)
let alter x = use (fun db -> Lwt_PGOCaml.alter db x)
