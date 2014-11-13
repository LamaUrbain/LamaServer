open Eliom_content
open Html5.D
open Html5.F

let navbar =
  nav ~a:[a_class ["navbar";"navbar-fixed-top"]]
    [
      a ~service:Site_services.main ~a:[a_class ["navbar-brand"]]
        [div ~a:[a_class ["navbar-header"]][pcdata  "Lama Urbain"]] ();
    ]

let div_container content = div ~a:[a_class ["container"]] content

let main_jumbotron =
  div ~a:[a_class ["jumbotron";"jumbo_main"]]
    [div_container
       [
         h1 [pcdata "Lama Urbain"];
         p [pcdata "Bienvenue sur Lama Urbain, le service d'itinéraire le plus ouvert du web !"]
       ]]

let format_page content =
  (Eliom_tools.F.html
     ~title:"Lama Urbain"
     ~css:[["css";"style.css"];["css";"bootstrap.css"];["css";"bootstrap-theme.css"]]
     (body [
         navbar;
         main_jumbotron
       ]))
