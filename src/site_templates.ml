open Eliom_content
open Html5.D
open Html5.F

let format_page content =
  (Eliom_tools.F.html
     ~title:"Lama Urbain"
     ~css:[["css";"style.css"];["css";"bootstrap.css"];["css";"bootstrap-theme.css"]]
     (body [
         div [h1 [pcdata "Lama Urbain"]];
         content
       ]))
