open Batteries
open Eliom_lib.Lwt_ops

let () =
  Eliom_registration.String.register
    ~service:Services.test
    (fun () () ->
       Lwt.return ("test", "text/plain")
    )
