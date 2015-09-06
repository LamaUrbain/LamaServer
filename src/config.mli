type postgres =
  { host : string
  ; port : int option
  ; database : string
  ; user : string
  ; password : string
  }

type mongodb =
  { host : string
  ; port : int
  ; name : string
  ; collection : string
  }

type database =
  | Postgres of postgres
  | MongoDB of mongodb

val map : string
val style : string
val database : database
