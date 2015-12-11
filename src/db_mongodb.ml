let empty = Bson.empty

let get_collection collection =
  match Config.database with
  | Config.MongoDB {Config.host; port; name} ->
    let mongo_addr _ =
      let addrinfo = List.hd @@ Unix.getaddrinfo host "" [] in
      match addrinfo.ai_addr with
      | ADDR_INET (a, i) -> Unix.string_of_inet_addr a
      | _ -> assert false
    in
    lazy (Mongo.create (mongo_addr ()) port name collection)
  | Config.Postgres _ ->
    lazy (assert false)

let user_collection = get_collection "users"

let gen_id _ = Random.int 50000

let create_user ~username ~password ~email ~sponsor =
  let id = gen_id() in
  let doc =
    empty
    |> Bson.add_element "username" (Bson.create_string username)
    |> Bson.add_element "password" (Bson.create_string password)
    |> Bson.add_element "email" (Bson.create_string email)
    |> Bson.add_element "sponsor" (Bson.create_boolean sponsor)
    |> Bson.add_element "id"
	  (id |> Int32.of_int |> Bson.create_int32)
  in
  Mongo.insert (Lazy.force user_collection) [doc];
  Lwt.return
    Users.{
      username;
      password;
      email;
      created = "";
	  sponsor = false;
      id;
    }

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
    let sponsor = Bson.get_element "sponsor" doc |> Bson.get_boolean in
    let open Users in
    Lwt.return (Some {username; password; email;id; sponsor; created})

let find_user_username username =
  empty
  |> Bson.add_element "username" (Bson.create_string username)
  |> Mongo.find_q (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ ->
    Lwt.return
      (Some
         Users.{
           username;
           password = Bson.get_element "password" doc |> Bson.get_string;
           sponsor = Bson.get_element "sponsor" doc |> Bson.get_boolean;
           email = Bson.get_element "email" doc |> Bson.get_string;
           id = Bson.get_element "id" doc |> Bson.get_int32 |> Int32.to_int;
           created = "";
         }
      )

let get_sponsored_users _ =
  empty
  |> Bson.add_element "sponsored" (Bson.create_boolean true)
  |> Mongo.find_q (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return []
  | doc ->
    Lwt.return
	  (List.map
	     (fun u ->
		    Users.{
		      username = Bson.get_element "username" u |> Bson.get_string;
		      password = Bson.get_element "password" u |> Bson.get_string;
		      sponsor = Bson.get_element "sponsor" u |> Bson.get_boolean;
		      email = Bson.get_element "email" u |> Bson.get_string;
		      id = Bson.get_element "id" u |> Bson.get_int32 |> Int32.to_int;
		      created = "";
	        }
	     ) doc)

let search_user username =
  empty
  |> Bson.add_element "sponsored" (Bson.create_string username)
  |> Mongo.find_q (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return []
  | doc ->
    Lwt.return
	  (List.map
	     (fun u ->
		    Users.{
		      username = Bson.get_element "username" u |> Bson.get_string;
		      password = Bson.get_element "password" u |> Bson.get_string;
		      sponsor = Bson.get_element "sponsor" u |> Bson.get_boolean;
		      email = Bson.get_element "email" u |> Bson.get_string;
		      id = Bson.get_element "id" u |> Bson.get_int32 |> Int32.to_int;
		      created = "";
	        }
	     ) doc)

let get_all_users _ =
  Mongo.find (Lazy.force user_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return []
  | doc ->
    Lwt.return
	  (List.map
	     (fun u ->
		    Users.{
		      username = Bson.get_element "username" u |> Bson.get_string;
		      password = Bson.get_element "password" u |> Bson.get_string;
		      sponsor = Bson.get_element "sponsor" u |> Bson.get_boolean;
		      email = Bson.get_element "email" u |> Bson.get_string;
		      id = Bson.get_element "id" u |> Bson.get_int32 |> Int32.to_int;
		      created = "";
	        }
	     ) doc)

let delete_user username =
  empty
  |> Bson.add_element "username" (Bson.create_string username)
  |> Mongo.delete_all (Lazy.force user_collection)
  |> Lwt.return

let auth_collection = get_collection "auth"

let gen_str length =
  let gen() = match Random.int(26+26+10) with
      n when n < 26 -> int_of_char 'a' + n
    | n when n < 26 + 26 -> int_of_char 'A' + n - 26
    | n -> int_of_char '0' + n - 26 - 26 in
  let gen _ = String.make 1 (char_of_int(gen())) in
  String.concat "" (Array.to_list (Array.init length gen))

let create_session ~(user : Users.t) =
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


let coords_collection = get_collection "coords"

let itineraries_collection = get_collection "itineraries"

let get_option fct opt acc = match opt with
  | None -> acc
  | Some x -> fct x acc

let create_coord coord =
  let open Request_data in
  empty
  |> get_option (fun x -> Bson.add_element "address" @@ Bson.create_string x) coord.address
  |> Bson.add_element "latitude" @@ Bson.create_double coord.latitude
  |> Bson.add_element "longitude" @@ Bson.create_double coord.longitude

let get_coord doc =
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

let create_itinerary ~owner ~name ~favorite ~departure ~destinations ~vehicle =
  let id =
    gen_id()
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
    |> Bson.add_element "departure" (Bson.create_doc_element @@ create_coord departure)
    |> Bson.add_element "destinations"
      (
        List.map (fun x -> Bson.create_doc_element @@ create_coord x) destinations
        |> Bson.create_list
      )
    |> Bson.add_element "vehicle" (Bson.create_int32 vehicle)
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
    vehicle;
  }
  |> (fun i -> Lwt.return (Some i))

let edit_user ~id ~username ~password ~email ~sponsor =
  let query = empty |> Bson.add_element "username" @@ Bson.create_string id in
  let doc =
    query
    |> get_option (fun x acc -> Bson.add_element "username" (Bson.create_string x) acc) username
    |> get_option (fun x acc -> Bson.add_element "email" (Bson.create_string x) acc) email
    |> get_option (fun x acc -> Bson.add_element "password" (Bson.create_string x) acc) password
    |> get_option (fun x acc -> Bson.add_element "sponsor" (Bson.create_boolean x) acc) sponsor
  in
  Mongo.update_one (Lazy.force user_collection) (query, doc)
  |> Lwt.return

let update_itinerary (itinerary : Result_data.itinerary) =
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
    |> Bson.add_element "departure" (create_coord itinerary.departure |> Bson.create_doc_element)
    |> Bson.add_element "destinations"
      (
        List.map (fun x -> create_coord x |> Bson.create_doc_element) itinerary.destinations
        |> Bson.create_list
      )
    |> Bson.add_element "vehicle" (Bson.create_int32 itinerary.vehicle)
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
  (Bson.get_element "departure" doc |> Bson.get_doc_element |> get_coord)
  >>= function
  | None -> Lwt.return None
  | Some departure ->
    Bson.get_element "destinations" doc
    |> Bson.get_list
    |> List.rev_map (fun x -> Bson.get_doc_element x |> get_coord)
    |> Lwt_list.fold_left_s
      (fun acc e ->
         e >>= (function Some x -> Lwt.return (x::acc) | None -> Lwt.return acc)
      )
      []
    >>= fun destinations ->
    Some
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
             Some (Bson.get_element "favorite" doc |> Bson.get_boolean)
           with _ -> None);
        departure;
        destinations;
        vehicle = Bson.get_element "vehicle" doc |> Bson.get_int32;
      }
    |> Lwt.return

let get_itinerary id =
  let open Lwt in
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.find_q_one (Lazy.force itineraries_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ -> _get_itinerary doc


let get_all_itineraries _ =
  let open Lwt in
  Mongo.find (Lazy.force itineraries_collection)
  |> MongoReply.get_document_list
  |> List.rev_map _get_itinerary
  |> Lwt_list.fold_left_s
    (fun acc e -> e >>= (function Some x -> Lwt.return (x::acc) | None -> Lwt.return acc))
    []

let incidents_collection = get_collection "incidents"

let create_incident ~name ~end_ ~position =
  let id =
    gen_id()
    |> Int32.of_int
  in
  let begin_ = CalendarLib.Calendar.now () in
  let doc =
    empty
    |> Bson.add_element "id" @@ Bson.create_int32 id
    |> Bson.add_element "name" @@ Bson.create_string name
    |> Bson.add_element "begin_" @@ Bson.create_double @@ CalendarLib.Calendar.to_unixfloat begin_
    |>
    get_option
      (fun x -> Bson.add_element "end_" (Bson.create_double @@ CalendarLib.Calendar.to_unixfloat x))
      end_
    |> Bson.add_element "position" (Bson.create_doc_element @@ create_coord position)
  in
  Mongo.insert (Lazy.force incidents_collection) [doc];
  Incident.{
    position;
    begin_;
    end_;
    id;
    name;
  }
  |> (fun x -> Lwt.return (Some x))

let delete_incident id =
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.delete_all (Lazy.force incidents_collection)
  |> Lwt.return


let _get_incident doc =
  let open Lwt in
  (Bson.get_element "position" doc |> Bson.get_doc_element |> get_coord)
  >>= function
  | None -> Lwt.return None
  | Some position ->
    Some
      Incident.{
        id = (Bson.get_element "id" doc |> Bson.get_int32);
        name = (Bson.get_element "name" doc |> Bson.get_string);
        begin_ = (
          Bson.get_element "begin_" doc
          |> Bson.get_double
          |> CalendarLib.Calendar.from_unixfloat
        );
        end_ =
          (try
             Some (
               Bson.get_element "end_" doc
               |> Bson.get_double
               |> CalendarLib.Calendar.from_unixfloat
             );
           with _ -> None);
        position;
      }
    |> Lwt.return


let get_incident id =
  let open Lwt in
  empty
  |> Bson.add_element "id" @@ Bson.create_int32 id
  |> Mongo.find_q_one (Lazy.force incidents_collection)
  |> MongoReply.get_document_list
  |> function
  | [] -> Lwt.return None
  | doc::_ -> _get_incident doc

let get_all_incidents () =
  let open Lwt in
  let now = CalendarLib.Calendar.now () in
  Mongo.find (Lazy.force incidents_collection)
  |> MongoReply.get_document_list
  |> List.rev_map _get_incident
  |> Lwt_list.fold_left_s
    (fun acc e -> e >>=
      (function
        | Some x ->
          begin
            if (BatOption.map_default (fun x -> x > now) true x.Incident.end_)
            then Lwt.return (x::acc)
            else Lwt.return acc
          end
        | None -> Lwt.return acc
      )
    )
    []
