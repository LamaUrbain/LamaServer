let to_gpx owner name lst =
  let author = Gpx.Make.person ~name:owner () in
  let metadata = Gpx.Make.metadata ?name ~author () in
  let waypoints { Result_data.departure; destinations; _ } =
    List.map
      (fun x -> Gpx.Make.wpt
        ?name:x.Request_data.address
        ~latitude:(Gpx.Make.latitude x.Request_data.latitude)
        ~longitude:(Gpx.Make.longitude x.Request_data.longitude) ())
    (departure :: destinations)
  in
  Gpx.Make.gpx
    ~metadata
    ~creator:"LamaUrbain"
    ~rtes:(List.map (fun rte -> Gpx.Make.rte ~routes:(waypoints rte) ()) lst) ()

let itineraries_to_gpx = to_gpx
let itinerary_to_gpx owner name itinerary = to_gpx owner name [ itinerary ]

module List =
struct
  include List

  let partition p l =
    List.fold_right
      (fun x (idx, a, b) -> if p idx x then idx + 1, x :: a, b else idx + 1, a, x :: b)
      l (0, [], [])
    |> fun (_, a, b) -> a, b

  let pop l =
    List.rev l |> List.tl |> List.rev
end

module Segment =
struct
  type t = Request_data.coord * Request_data.coord

  let make a b = (a, b)

  (* flemme *)
  let ( - ) = ( -. )
  let ( + ) = ( +. )
  let ( * ) = ( *. )
  let ( / ) = ( /. )

  let distance point segment =
    let distance a b =
      (a.Request_data.latitude - b.Request_data.latitude) ** 2.
      + (a.Request_data.longitude - b.Request_data.longitude) ** 2. in
    let aux p (a, b) =
      let l = distance a b in
      if l = 0.
      then distance point a
      else
        let open Request_data in
        let t = ((p.latitude - a.latitude) * (b.latitude - a.latitude)
                 + (p.longitude - a.longitude) * (b.longitude - a.longitude))
                / l
        in
        if t < 0. then distance p a
        else if t > 1. then distance p b
        else distance p
               { address = None
               ; latitude = a.latitude + t * (b.latitude - a.latitude)
               ; longitude = a.longitude + t * (b.longitude - a.latitude) }
     in sqrt (aux point segment)
end

let rec douglas_peucker epsilon lst =
  let dmax  = ref 0. in
  let index = ref 0 in
  let plist = Array.of_list lst in
  let e     = Array.length plist - 1 in

  for i = 1 to e
  do
    let d = Segment.distance plist.(i) (Segment.make plist.(0) plist.(e)) in
    if d > !dmax then begin
      index := i;
      dmax  := d;
    end
  done;

  if !dmax >= epsilon
  then
    let a, b = List.partition (fun idx _ -> idx < !index) lst in
    let a = douglas_peucker epsilon a in
    let b = douglas_peucker epsilon b in
    (List.pop a) @ b
  else
    lst

let of_gpx { Gpx.wpt; Gpx.metadata; _ } =
  let open Result_data in
  let ( >>= ) a f = match a with Some x -> f x | None -> None in
  let owner = metadata >>= (function { Gpx.author; _ } -> author)
                       >>= (function { Gpx.name; _ } -> name) in
  let name  = metadata >>= (function { Gpx.name; _ } -> name) in
  let wpt   =
    List.map
      (fun { Gpx.lat; Gpx.lon; Gpx.name; _ } ->
        { Request_data.latitude = lat
        ; Request_data.longitude = lon
        ; Request_data.address = name }) (* XXX: maybe not name. *)
      wpt
    |> douglas_peucker 1. in
  let creation = "" (* ? *) in
  let favorite = None in
  let departure = List.hd wpt in
  let destinations = List.tl wpt in
  { id = Int32.zero (* ? *)
  ; owner
  ; name
  ; creation
  ; favorite
  ; departure
  ; destinations
  ; vehicle = Int32.zero (* ? *) }
