val itineraries_to_gpx : string -> string option -> Result_data.itinerary list -> Gpx.gpx
val itinerary_to_gpx : string -> string option -> Result_data.itinerary -> Gpx.gpx
val of_gpx : Gpx.gpx -> Result_data.itinerary
