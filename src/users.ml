type t =
  { username : string;
    password : string;
    email : string;
    created : string;
    id : int;
  } [@@deriving yojson]

type users = t list [@@deriving yojson]
