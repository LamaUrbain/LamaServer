#include <osmscout/Database.h>
#include <osmscout/MapService.h>

#include <osmscout/MapPainterCairo.h>

#include <osmscout/RoutingService.h>
#include <osmscout/POIService.h>
#include <osmscout/RoutePostprocessor.h>
#include <osmscout/util/Geometry.h>
#include <osmscout/util/Tiling.h>

struct Point {
    osmscout::ObjectFileRef object;
    size_t nodeIndex;
};

struct Itinerary {
    osmscout::WayRef way;
};

class Painter : public osmscout::MapPainterCairo {
public:
    Painter(const osmscout::StyleConfigRef& styleConfig)
    : osmscout::MapPainterCairo(styleConfig) {
    }

    void DrawGround(const osmscout::Projection&,
                    const osmscout::MapParameter&,
                    const osmscout::FillStyle&) {
    }
};

static void GetCarSpeedTable(std::map<std::string,double>& map)
{
    map["highway_motorway"]=110.0;
    map["highway_motorway_trunk"]=100.0;
    map["highway_motorway_primary"]=70.0;
    map["highway_motorway_link"]=60.0;
    map["highway_motorway_junction"]=60.0;
    map["highway_trunk"]=100.0;
    map["highway_trunk_link"]=60.0;
    map["highway_primary"]=70.0;
    map["highway_primary_link"]=60.0;
    map["highway_secondary"]=60.0;
    map["highway_secondary_link"]=50.0;
    map["highway_tertiary_link"]=55.0;
    map["highway_tertiary"]=55.0;
    map["highway_unclassified"]=50.0;
    map["highway_road"]=50.0;
    map["highway_residential"]=40.0;
    map["highway_roundabout"]=40.0;
    map["highway_living_street"]=10.0;
    map["highway_service"]=30.0;
}

static const double DPI=96.0;

static osmscout::DatabaseRef g_database = NULL;
static osmscout::StyleConfigRef g_styleConfig = NULL;

extern "C"
bool init(char* map, char* style) {
    // Database
    osmscout::DatabaseParameter databaseParameter;

    g_database = osmscout::DatabaseRef(new osmscout::Database(databaseParameter));

    if (!g_database->Open(map)) {
        std::cerr << "Cannot open database" << std::endl;
        return false;
    }

    // Style
    g_styleConfig = osmscout::StyleConfigRef(new osmscout::StyleConfig(g_database->GetTypeConfig()));

    if (!g_styleConfig->Load(style)) {
        std::cerr << "Cannot open style" << std::endl;
        return false;
    }

    return true;
}

static osmscout::Vehicle getVehicle(int32_t vehicleIdx) {
    switch (vehicleIdx) {
    case 0:
        return osmscout::vehicleFoot;
    case 1:
        return osmscout::vehicleBicycle;
    case 2:
        return osmscout::vehicleCar;
    default:
        return osmscout::vehicleFoot;
    }
}

static osmscout::FastestPathRoutingProfileRef getRoutingProfile(osmscout::Vehicle vehicle) {
    osmscout::TypeConfigRef typeConfig = g_database->GetTypeConfig();
    osmscout::FastestPathRoutingProfileRef routingProfile = osmscout::FastestPathRoutingProfileRef(new osmscout::FastestPathRoutingProfile(typeConfig));

    switch (vehicle) {
    case osmscout::vehicleFoot:
        routingProfile->ParametrizeForFoot(*typeConfig, 5.0);
        break;
    case osmscout::vehicleBicycle:
        routingProfile->ParametrizeForBicycle(*typeConfig, 20.0);
        break;
    case osmscout::vehicleCar:
        std::map<std::string, double> carSpeedTable;

        GetCarSpeedTable(carSpeedTable);
        routingProfile->ParametrizeForCar(*typeConfig, carSpeedTable, 160.0);
        break;
    }

    return routingProfile;
}

static osmscout::RoutingServiceRef getRouter(osmscout::Vehicle vehicle) {
    bool outputGPX = false;
    osmscout::RouterParameter routerParameter;

    if (!outputGPX) {
        routerParameter.SetDebugPerformance(true);
    }

    osmscout::RoutingServiceRef router(new osmscout::RoutingService(g_database, routerParameter, vehicle));

    if (!router->Open()) {
        std::cerr << "Cannot open routing database" << std::endl;
        return NULL;
    }

    return router;
}

extern "C"
struct Point* createPoint(float lat, float lon) {
    osmscout::ObjectFileRef object;
    size_t nodeIndex;
    auto result = new Point;

    auto vehicle = osmscout::vehicleFoot;
    auto router = getRouter(vehicle);

    if (router == NULL) {
        return NULL;
    }

    if (!router->GetClosestRoutableNode(lat, lon, vehicle, 1000, object, nodeIndex)) {
        std::cerr << "Error while searching for routing node near location !" << std::endl;
        return NULL;
    }

    if (object.Invalid() || object.GetType() == osmscout::refNode) {
        std::cerr << "Cannot find start node for location !" << std::endl;
        return NULL;
    }

    result->object = object;
    result->nodeIndex = nodeIndex;
    return result;
}

extern "C"
struct Itinerary* createItinerary(const struct Point* start, const struct Point* target, int32_t vehicleIdx) {
    auto way = new osmscout::Way;
    auto result = new Itinerary;
    osmscout::RouteData data;

    auto vehicle = getVehicle(vehicleIdx);
    auto routingProfile = getRoutingProfile(vehicle);
    auto router = getRouter(vehicle);

    if (router == NULL) {
        return NULL;
    }

    if (!router->CalculateRoute(*routingProfile, start->object, start->nodeIndex, target->object, target->nodeIndex, data)) {
        std::cerr << "There was an error while calculating the route!" << std::endl;
        return NULL;
    }

    if (data.IsEmpty()) {
        std::cout << "No Route found!" << std::endl;
        return NULL;
    }

    if (!router->TransformRouteDataToWay(data, *way)) {
        std::cerr << "Cannot transform route date to way" << std::endl;
        return NULL;
    }

    result->way = osmscout::WayRef(way);
    return result;
}

extern "C"
osmscout::Magnification* getMagnification(uint32_t z) {
    auto magnification = new osmscout::Magnification;

    magnification->SetLevel(z);

    return magnification;
}

extern "C"
void iterCoordinates(const Itinerary* itinerary,
                     const osmscout::Magnification* magnification,
                     void (*f)(size_t, size_t)) {
    auto way = itinerary->way;

    for (auto it = way->nodes.begin(); it != way->nodes.end(); ++it) {
        size_t x = osmscout::LonToTileX(it->lon, *magnification);
        size_t y = osmscout::LatToTileY(it->lat, *magnification);

        f(x, y);
    }
}

extern "C"
osmscout::MapData* createMapData() {
    return new osmscout::MapData;
}

extern "C"
void addMapData(osmscout::MapData* data, const Itinerary* itinerary) {
    data->poiWays.push_back(itinerary->way);
}

extern "C"
bool paint(size_t x, size_t y,
           size_t width, size_t height,
           const osmscout::MapData* data,
           const osmscout::Magnification* magnification,
           cairo_t* cairo) {
    osmscout::TileProjection projection;
    osmscout::MapParameter drawParameter;
    Painter painter(g_styleConfig);

    drawParameter.SetFontSize(3.0);
    projection.Set(x, y, *magnification, DPI, width, height);

    return painter.DrawMap(projection, drawParameter, *data, cairo);
}



#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <stdint.h>

extern "C"
value cairo_address(value v)
{
    return caml_copy_nativeint(*(intptr_t *)Data_custom_val(v));
}
