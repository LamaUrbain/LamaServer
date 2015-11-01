type t =
  {
    name : string;
    id : int32;
    begin_ : CalendarLib.Calendar.t;
    end_ : CalendarLib.Calendar.t option;
    position : Request_data.coord;
  }
