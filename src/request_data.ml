type user_creation =
  { username : string;
    password : string;
    email : string;
  } [@@deriving yojson]

type geo_coord =
  { latitude : float
  ; longitude : float
  }

type itinerary_creation =
  { points : Yojson.Safe.json list
(*  ; settings : settings *)
  } [@@deriving yojson]

type id = { id : int } [@@deriving yojson]
