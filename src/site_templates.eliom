open Eliom_content
open Html5.D

let get_image ?alt:(alt="Lama Urbain") ~name =
  img ~alt:("Lama Urbain") ~src:(
    make_uri
      ~service: (Eliom_service.static_dir ())
      ["img"; name]
  ) ()

let format_page content =
  let ol =  Html5.F.uri_of_string (fun _ ->
    "http://openlayers.org/en/v3.1.1/build/ol.js") in
  let ol_script =  make_uri ~service:(Eliom_service.static_dir ()) ["js"; "map.js"] in
  (Eliom_tools.F.html
     ~title:"Lama Urbain"

     ~css:[["bower";"bootstrap";"dist";"css";"bootstrap.min.css"];
           ["bower";"fontawesome";"css";"font-awesome.min.css"];
           ["css";"style.css"]]

     ~js:[
        ["v3.1.1";"closure-library";"closure";"goog";"base.js"];
       ["v3.1.1";"build";"ol-deps.js"];
       ["v3.1.1";"build";"ol.js"];
          ["bower";"jquery";"dist";"jquery.min.js"];
          ["bower";"bootstrap";"dist";"js";"bootstrap.min.js"];
          ["bower";"less";"dist";"less.min.js"]]
     Html5.F.(body
     (List.append content [div ~a:[a_id "map"; a_class["map"]] []; js_script ~a:[a_defer `Defer] ~uri:ol_script ()])
             )
  )


