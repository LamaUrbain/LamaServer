let rec list_insert pos elm = function
  | _ when pos = 0 -> [elm]
  | [] -> raise Not_found
  | x::xs -> x :: list_insert (pred pos) elm xs
