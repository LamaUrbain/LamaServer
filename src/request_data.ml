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
  ; favorite : bool option
  } [@@deriving yojson]

type itinerary_edition =
  { name : string option
  ; departure : coord option
  ; favorite : bool option
  } [@@deriving yojson]

type add_destination =
  { destination : coord
  ; position : int option
  } [@@deriving yojson]
