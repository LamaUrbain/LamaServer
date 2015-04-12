type user_creation =
  { username : string;
    password : string;
    email : string;
  } deriving (Yojson)

type geo_coord =
  { latitude : float
  ; longitude : float
  } deriving (Yojson)

type coord_content =
  | Adresse of string
  | GeoCoordinates of geo_coord
  deriving (Yojson)

type coord =
  { (* type : string *)
    content : coord_content
  } deriving (Yojson)

type itinerary_creation =
  { points : coord list
(*  ; settings : settings *)
  } deriving (Yojson)

type id = { id : int } deriving (Yojson)
