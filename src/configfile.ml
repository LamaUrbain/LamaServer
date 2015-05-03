open BatteriesExceptionless
open Monomorphic

let fmt = Printf.sprintf

let fail_attrib ~tag x =
  let msg = fmt "Unexpected attribute '%s' inside '%s'" x tag in
  raise (Ocsigen_extensions.Error_in_config_file msg)

let fail_content ~tag =
  let msg = fmt "Unexpected content inside '%s'" tag in
  raise (Ocsigen_extensions.Error_in_config_file msg)

let fail_tag ~tag =
  let msg = fmt "Unexpected tag '%s'" tag in
  raise (Ocsigen_extensions.Error_in_config_file msg)

let fail_pcdata x =
  let msg = fmt "Unexpected pcdata '%s' inside cumulus" x in
  raise (Ocsigen_extensions.Error_in_config_file msg)

let fail_missing ~tag x =
  let msg = fmt "Missing attribute '%s' inside '%s'" x tag in
  raise (Ocsigen_extensions.Error_in_config_file msg)

let fail_missing_tag ~tag =
  let msg = fmt "Missing tag '%s'" tag in
  raise (Ocsigen_extensions.Error_in_config_file msg)
