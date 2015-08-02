let empty = Bson.empty

let mongo_addr _ =
  let addrinfo = List.hd @@ Unix.getaddrinfo "mongo" "" []
  in match addrinfo.ai_addr with
     | ADDR_INET (a,i) -> Unix.string_of_inet_addr a
     | otherwise -> assert false

let user_collection = lazy (Mongo.create (mongo_addr ()) 27017 "lamaurbain" "users")

let create_user ~username ~password ~email =
  try
    let doc =
      empty
      |> Bson.add_element "username" (Bson.create_string username)
      |> Bson.add_element "password" (Bson.create_string password)
      |> Bson.add_element "email" (Bson.create_string email)
      |> Bson.add_element "id"
        (Lazy.force user_collection |> Mongo.count |> Int32.of_int |> Bson.create_int32)
    in
    Mongo.insert (Lazy.force user_collection) [doc];
    Lwt.return
      Users.{
        username;
        password;
        email;
        created = "";
        id=0;
      }
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

let find_user_username username =
  empty
  |> Bson.add_element "username" (Bson.create_string username)
  |> Mongo.find_q_one (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ ->
    Lwt.return
      (Some
         Users.{
           username;
           password = Bson.get_element "password" doc |> Bson.get_string;
           email = Bson.get_element "email" doc |> Bson.get_string;
           id = Bson.get_element "id" doc |> Bson.get_int32 |> Int32.to_int;
           created = "";
         }
      )

let delete_user username =
  empty
  |> Bson.add_element "username" (Bson.create_string username)
  |> Mongo.delete_all (Lazy.force user_collection)
  |> Lwt.return

let auth_collection = lazy (Mongo.create (mongo_addr ()) 27017 "lamaurbain" "auth")

let gen_str length =
  let gen() = match Random.int(26+26+10) with
      n when n < 26 -> int_of_char 'a' + n
    | n when n < 26 + 26 -> int_of_char 'A' + n - 26
    | n -> int_of_char '0' + n - 26 - 26 in
  let gen _ = String.make 1 (char_of_int(gen())) in
  String.concat "" (Array.to_list (Array.init length gen))

let create_session ~user =
  let token = gen_str 32 in
  let owner = user.Users.username in
  let doc =
    empty
    |> Bson.add_element "token" (Bson.create_string token)
    |> Bson.add_element "owner" (Bson.create_string owner)
  in
  Mongo.insert (Lazy.force auth_collection) [doc];
  Lwt.return
    Sessions.({
        token;
        owner;
        created = "";
      })

let find_session token =
  empty
  |> Bson.add_element "token" (Bson.create_string token)
  |> Mongo.find_q_one (Lazy.force auth_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ ->
    Some
      Sessions.{
        token;
        owner = Bson.get_element "owner" doc |> Bson.get_string;
        created = "";
      }
    |> Lwt.return

let delete_session token =
  empty
  |> Bson.add_element "token" (Bson.create_string token)
  |> Mongo.delete_all (Lazy.force user_collection)
  |> Lwt.return


let coords_collection =
  lazy (Mongo.create (mongo_addr ()) 27017 "lamaurbain" "coords")

let itineraries_collection =
  lazy (Mongo.create (mongo_addr ()) 27017 "lamaurbain" "itineraries")

let get_option fct opt acc = match opt with
  | None -> acc
  | Some x -> fct x acc

let create_coord coord =
  let open Request_data in
  let id =
    Lazy.force coords_collection
    |> Mongo.count
    |> Int32.of_int
  in
  let doc =
    empty
    |> Bson.add_element "id" @@ Bson.create_int32 id
    |> get_option (fun x -> Bson.add_element "address" @@ Bson.create_string x) coord.address
    |> Bson.add_element "latitude" @@ Bson.create_double coord.latitude
    |> Bson.add_element "longitude" @@ Bson.create_double coord.longitude
  in
  Mongo.insert (Lazy.force coords_collection) [doc];
  id

let get_coord id =
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.find_q_one (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ ->
    Some
      Request_data.{
        address =
          (try
             Some (Bson.get_element "address" doc |> Bson.get_string)
           with _ -> None)
        ;
        latitude = Bson.get_element "latitude" doc |> Bson.get_double;
        longitude = Bson.get_element "longitude" doc |> Bson.get_double;
      }
  |> Lwt.return

let create_itinerary ~owner ~name ~favorite ~departure ~destinations =
  let id =
    Lazy.force itineraries_collection
    |> Mongo.count
    |> Int32.of_int
  in
  let doc =
    empty
    |> Bson.add_element "id" @@ Bson.create_int32 id
    |>
    get_option
      (fun x acc -> Bson.add_element "owner" (Bson.create_string x) acc)
      owner
    |>
    get_option
      (fun x acc -> Bson.add_element "name" (Bson.create_string x) acc)
      name
    |> Bson.add_element "creation" @@ Bson.create_string ""
    |>
    get_option
      (fun x acc -> Bson.add_element "favorite" (Bson.create_boolean x) acc)
      favorite
    |> Bson.add_element "departure" (create_coord departure |> Bson.create_int32)
    |> Bson.add_element "destinations"
      (
        List.map (fun x -> create_coord x |> Bson.create_int32) destinations
        |> Bson.create_list
      )
  in
  Mongo.insert (Lazy.force itineraries_collection) [doc];
    Result_data.{
      id;
      owner;
      name;
      creation = "";
      favorite;
      departure;
      destinations;
    }
  |> Lwt.return

let update_itinerary itinerary =
  let open Result_data in
  let query =
    empty
    |> Bson.add_element "id" @@ Bson.create_int32 itinerary.id
  in
  let doc =
    query
    |>
    get_option
      (fun x acc -> Bson.add_element "owner" (Bson.create_string x) acc)
      itinerary.owner
    |>
    get_option
      (fun x acc -> Bson.add_element "name" (Bson.create_string x) acc)
      itinerary.name
    |>
    get_option
      (fun x acc -> Bson.add_element "favorite" (Bson.create_boolean x) acc)
      itinerary.favorite
    |> Bson.add_element "departure" (create_coord itinerary.departure |> Bson.create_int32)
    |> Bson.add_element "destinations"
      (
        List.map (fun x -> create_coord x |> Bson.create_int32) itinerary.destinations
        |> Bson.create_list
      )
  in
  Mongo.update_one (Lazy.force itineraries_collection) (query,doc)
  |> Lwt.return

let delete_itinerary id =
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.delete_all (Lazy.force itineraries_collection)
  |> Lwt.return

let _get_itinerary doc =
  let open Lwt in
  (Bson.get_element "departure" doc |> Bson.get_int32 |> get_coord)
  >>= function
    | None -> Lwt.return None
    | Some departure ->
      Bson.get_element "destinations" doc
      |> Bson.get_list
      |> List.rev_map (fun x -> Bson.get_int32 x |> get_coord)
      |> Lwt_list.fold_left_s
        (fun acc e ->
           e >>= (function Some x -> Lwt.return (x::acc) | None -> Lwt.return acc)
        )
        []
      >>= fun destinations ->
      Lwt.return
        Result_data.{
          id = (Bson.get_element "id" doc |> Bson.get_int32);
          owner =
            (try
               Some (Bson.get_element "owner" doc |> Bson.get_string)
             with _ -> None)
          ;
          name =
            (try
               Some (Bson.get_element "name" doc |> Bson.get_string)
             with _ -> None);
          creation = "";
          favorite =
            (try
               Some (Bson.get_element "favorite" doc |> Bson.get_double)
             with _ -> None);
          departure;
          destinations;
        }

let get_itinerary id =
  let open Lwt in
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.find_q_one (Lazy.force itineraries_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ -> _get_itinerary doc


let get_all_itineraries =
  empty
  |> Mongo.find (Lazy.force itineraries_collection)
  |> MongoReply.get_document_list
  |> Lwt.rev_map_s _get_itinerary
     >>= Lwt_list.fold_left_s (fun acc -> function Some x -> x::acc | None -> acc)
