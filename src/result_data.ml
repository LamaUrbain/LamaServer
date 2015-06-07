type itinerary =
  { id : int
  ; owner : string option
  ; name : string option
  ; creation : string
  ; favorite : bool option
  ; departure : Request_data.coord
  ; destinations : Request_data.coord list
  } [@@deriving yojson]
