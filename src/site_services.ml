open Batteries
open Eliom_lib.Lwt_ops

open Eliom_service
open Eliom_parameter

let test =
  Http.service
    ~path:[]
    ~get_params:unit
    ()
