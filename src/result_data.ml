type itinerary =
  { id : int
  ; owner : string option
  ; creation : string
  ; favorite : bool
  ; departure : Request_data.coord
  ; destinations : Request_data.coord list
  } [@@deriving yojson]
