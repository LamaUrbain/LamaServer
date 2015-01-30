open Eliom_content
open Html5.D

let navbar =
  nav ~a:[a_class ["navbar";"navbar-fixed-top";"navbar-urbain"]]
    [
      a ~service:Site_services.main ~a:[a_class ["navbar-brand"]]
        [div ~a:[a_class ["navbar-header"]][pcdata  "Lama Urbain"]] ();
    ]

let div_container ~content ~classes =
  div ~a:[a_class (List.append ["container"] classes)] content

let get_image ?alt:(alt="Lama Urbain") ~name =
  img ~alt:("Lama Urbain") ~src:(
    make_uri
      ~service: (Eliom_service.static_dir ())
      ["img"; name]
  ) ()

let main_jumbotron =
  div ~a:[a_class ["jumbotron";"jumbo_main"]]
    [div_container
       ~classes:["media"]
       ~content:
         [
           div ~a:[a_class["media-left"]]
           [
               get_image ~alt:"Lama Urbain" ~name:"lamaurbain_little.png"
           ];
           div ~a:[a_class["media-body"]]
           [
             pcdata "Bienvenue sur Lama Urbain: le service d'itinéraire le plus ouvert du web !";
                 br ();
                 br ()
           ]
        ]
    ]

let format_page content =
  (Eliom_tools.F.html
     ~title:"Lama Urbain"

     ~css:[["bower";"bootstrap";"dist";"css";"bootstrap.min.css"];
           ["bower";"fontawesome";"css";"font-awesome.min.css"];
           ["css";"style.css"]]

     ~js:[["ol";"ol.js"];
          ["bower";"jquery";"dist";"jquery.min.js"];
          ["bower";"bootstrap";"dist";"js";"bootstrap.min.js"]]
     Html5.F.(body content)
  )
