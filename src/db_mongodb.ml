let empty = Bson.empty

let user_collection =
  Mongo.create_local_default "lamaurbain" "users"

let create_user ~username ~password ~email =
  let doc =
    empty
    |> Bson.add_element "username" (Bson.create_string username)
    |> Bson.add_element "password" (Bson.create_string password)
    |> Bson.add_element "email" (Bson.create_string email)
    |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int (Mongo.count
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

