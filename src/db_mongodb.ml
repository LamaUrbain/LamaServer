let empty = Bson.empty

let mongo_addr _ =
  let addrinfo = List.hd @@ Unix.getaddrinfo "mongo" "" []
  in match addrinfo.ai_addr with
     | ADDR_INET (a,i) -> Unix.string_of_inet_addr a
     | otherwise -> assert false

let user_collection = lazy (Mongo.create (mongo_addr ()) 27017 "lamaurbain" "users")

let create_user ~username ~password ~email =
  try
    let open Users in
    let doc =
      empty
      |> Bson.add_element "username" (Bson.create_string username)
      |> Bson.add_element "password" (Bson.create_string password)
      |> Bson.add_element "email" (Bson.create_string email)
      |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int (Mongo.count
								   @@ Lazy.force user_collection)) in
    Mongo.insert (Lazy.force user_collection) [doc];
    Lwt.return
      Users.(
      {
        username;
        password;
        email;
	created = "";
        id=0;
      }
    )
  with
  | _ -> assert false

let find_user id =
  let query =
    empty
    |> Bson.add_element "id" (Bson.create_int32 @@ Int32.of_int id) in
  let response = Mongo.find_q_one (Lazy.force user_collection) query in
  match MongoReply.get_document_list response with
  | [] -> Lwt.return None
  | doc::_ ->
      let username = Bson.get_element "username" doc |> Bson.get_string in
      let password = Bson.get_element "password" doc |> Bson.get_string in
      let email = Bson.get_element "email" doc |> Bson.get_string in
      let created = "" in 
      let open Users in
      Lwt.return (Some {username; password; email;id; created})
