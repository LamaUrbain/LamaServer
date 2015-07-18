type t =
  { token : string;
    created : string;
    owner : Int32.t;
  } [@@deriving yojson]
