type user_creation =
  { username : string;
    password : string;
    email : string;
  } [@@deriving yojson]

type coord =
  { typ [@key "type"] : string
  ; content : Yojson.Safe.json
  } [@@deriving yojson]

type itinerary_creation =
  { points : coord list
(*  ; settings : settings *)
  } [@@deriving yojson]

type id = { id : int } [@@deriving yojson]
