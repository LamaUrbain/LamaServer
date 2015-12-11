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
