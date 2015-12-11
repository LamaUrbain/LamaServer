type t =
  {
    name : string;
    id : int32;
    begin_ : Calendar.t [@key "begin"];
    end_ : Calendar.t option [@key "end"];
    position : Request_data.coord;
  } [@@deriving yojson]

type incidents = t list [@@deriving yojson]

type incidents_response = t list [@@deriving yojson]

let to_response t = t
