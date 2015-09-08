type t =
  { username : string;
    password : string;
    email : string;
    created : string;
    sponsor : bool;
    id : int;
  } [@@deriving yojson]

type response =
  { username : string;
    email : string;
    sponsor : bool;
  } [@@deriving yojson]


type users = t list [@@deriving yojson]

type users_response = response list [@@deriving yojson]

let to_response {username; password; email; created; sponsor;id} =
  {username;email;sponsor}
