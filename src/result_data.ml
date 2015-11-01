type itinerary =
  { id : int32
  ; owner : string option
  ; name : string option
  ; creation : string
  ; favorite : bool option
  ; departure : Request_data.coord
  ; destinations : Request_data.coord list
  } [@@deriving yojson]

type incident =
  {
    id : int32;
    name : string option;
    begin_ : string;
    end_ : string;
    position : Request_data.cood;
  } [@@deriving yojson]
