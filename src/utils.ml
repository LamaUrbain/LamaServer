let rec list_insert pos elm = function
  | _ when pos = 0 -> [elm]
  | [] -> raise Not_found
  | x::xs -> x :: list_insert (pred pos) elm xs

let rec list_take_at pos = function
  | x::xs when pos = 0 -> (x, xs)
  | [] -> raise Not_found
  | x::xs ->
      let (y, xs) = list_take_at (pred pos) xs in
      (y, x :: xs)
