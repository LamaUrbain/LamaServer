open Eliom_content
open Html5.D

let get_image ?alt:(alt="Lama Urbain") ~name =
  img ~alt:("Lama Urbain") ~src:(
    make_uri
      ~service: (Eliom_service.static_dir ())
      ["img"; name]
  ) ()

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
