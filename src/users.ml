type t =
  { username : string;
    password : string;
    email : string;
    id : int;
  } [@@deriving yojson]
