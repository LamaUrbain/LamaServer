(* OASIS_START *)
(* OASIS_STOP *)

module M = Ocamlbuild_eliom.Make(struct
  let client_dir = "client"
  let server_dir = "server"
  let type_dir = "type"
end)

let () =
  dispatch
    (fun hook ->
       dispatch_default hook;
       M.dispatcher
         ~oasis_executables:["src/client/lama_server.byte"]
         hook;
    )
