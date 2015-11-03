type t = CalendarLib.Calendar.t

let to_yojson (date : t) =
  let date_string = CalendarLib.Printer.Calendar.to_string date in
  Yojson.Safe.from_string date_string

let of_yojson (date : Yojson.Safe.json) =
  try
    let date_string = Yojson.Safe.to_string date in
    `Ok (CalendarLib.Printer.Calendar.from_string date_string)
  with
  | _ -> `Error "Error while parsing date"
