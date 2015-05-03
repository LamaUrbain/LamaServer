open BatteriesExceptionless
open Monomorphic

let rec init_fun data = function
  | Simplexmlparser.Element ("config" as tag, attribs, content)::l ->
      if content <> [] then
        Configfile.fail_content ~tag;
      let data =
        List.fold_left
          (fun (map, style) -> function
             | "map", x -> (Some x, style)
             | "style", x -> (map, Some x)
             | x, _ -> Configfile.fail_attrib ~tag x
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

let (map, style) =
  let data = (None, None) in
  let c = Eliom_config.get_config () in
  match init_fun data c with
  | (Some map, Some style) -> (map, style)
  | (None, Some _) -> Configfile.fail_missing ~tag:"config" "map"
  | (Some _, None) -> Configfile.fail_missing ~tag:"config" "style"
  | (None, None) -> Configfile.fail_missing_tag ~tag:"config"
