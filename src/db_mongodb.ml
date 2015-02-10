let empty = Bson.empty

let count ?skip ?limit ?(query=Bson.empty) m =
  let c_bson = Bson.add_element "query" (Bson.create_doc_element query)
      empty in
  let c_bson = Bson.add_element "count" (Bson.create_string "users")
      c_bson in
  let c_bson =
    match limit with
    | Some n -> Bson.add_element "limit" (Bson.create_int32
                                            (Int32.of_int n)) c_bson
    | None -> c_bson
  in
  let m = Mongo.change_collection m
      "$cmd" in
  let r = Mongo.find_q_one m
      c_bson in
  let d = List.nth
      (MongoReply.get_document_list
         r) 0 in
  int_of_float
    (Bson.get_double
       (Bson.get_element "n"
          d))

let user_collection =
  Mongo.create_local_default "lamaurbain" "users"

let create_user ~username ~password ~email =
  let doc =
    empty
    |> Bson.add_element "username" (Bson.create_string username)
    |> Bson.add_element "password" (Bson.create_string password)
    |> Bson.add_element "email" (Bson.create_string email)
    |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int (count
    user_collection)) in
  Mongo.insert user_collection [doc];
  let open Users in
  {username; password; email}

let find_user id =
  let query =
    empty
    |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int id) in
  let response = Mongo.find_q_one user_collection query in
  match MongoReply.get_document_list response with
  | [] -> None
  | doc::_ ->
      let username = Bson.get_element "username" doc |> Bson.get_string in
      let password = Bson.get_element "password" doc |> Bson.get_string in
      let email = Bson.get_element "email" doc |> Bson.get_string in
      let open Users in
      Some {username; password; email}

