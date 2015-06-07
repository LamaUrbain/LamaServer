type user_creation =
  { username : string;
    password : string;
    email : string;
  } [@@deriving yojson]

type coord =
  { address : string option
  ; latitude : float
  ; longitude : float
  } [@@deriving yojson]

type itinerary_creation =
  { name : string option
  ; departure : coord
  ; destination : coord option
  ; favorite : bool
  } [@@deriving yojson]
