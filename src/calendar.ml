type t = CalendarLib.Calendar.t

let to_yojson (date : t) = Yojson.Safe.from_string "lol"

let of_yojson (date : Yojson.Safe.json) = `Ok (CalendarLib.Calendar.now ())
