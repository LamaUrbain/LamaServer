open Batteries
open Eliom_lib.Lwt_ops

let () =
  Eliom_registration.Html5.register
    ~service:Site_services.main
    (fun () () ->
      Lwt.return @@ Site_templates.format_page [Eliom_content.Html5.F.pcdata "lol"]
    )
