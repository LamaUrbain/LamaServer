type t = CalendarLib.Calendar.t

let to_string = CalendarLib.Printer.Calendar.to_string

let from_string = CalendarLib.Printer.Calendar.from_string

let to_yojson (date : t) =
  let date_string = to_string date in
  `String date_string

let of_yojson (date : Yojson.Safe.json) =
  try
    let date_string = Yojson.Safe.to_string date in
    `Ok (CalendarLib.Printer.Calendar.from_string date_string)
  with
  | _ -> `Error "Error while parsing date"
