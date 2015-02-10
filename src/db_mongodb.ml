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

let get_user_collection _ =
  Mongo.create_local_default "lamaurbain" "users"

let create_user ~username ~password ~email =
  let m = get_user_collection () in
  let doc =
    empty
    |> Bson.add_element "username" (Bson.create_string username)
    |> Bson.add_element "password" (Bson.create_string password)
    |> Bson.add_element "email" (Bson.create_string email)
    |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int (count m)) in
  Mongo.insert m [doc];
  let open Users in
  {username; password; email}


