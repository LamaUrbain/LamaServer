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
    osmscout::StyleConfigRef styleConfig;
};

class Painter : public osmscout::MapPainterCairo {
public:
    Painter(const osmscout::StyleConfigRef& styleConfig)
    : osmscout::MapPainterCairo(styleConfig) {
    }

    void DrawGround(const osmscout::Projection& projection,
                    const osmscout::MapParameter& parameter,
                    const osmscout::FillStyle& style) {
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

static osmscout::Vehicle g_vehicle = osmscout::vehicleCar;
static osmscout::RoutingServiceRef g_router = NULL;
static osmscout::StyleConfigRef g_styleConfig = NULL;
static osmscout::FastestPathRoutingProfileRef g_routingProfile = NULL;

extern "C"
bool init(const char* map, const char* style) {
    bool outputGPX = false;
    osmscout::DatabaseParameter databaseParameter;
    osmscout::DatabaseRef database(new osmscout::Database(databaseParameter));
    osmscout::RouterParameter routerParameter;
    osmscout::RouteDescription description;
    std::map<std::string, double> carSpeedTable;

    if (!database->Open(map)) {
        std::cerr << "Cannot open database" << std::endl;
        return false;
    }

    auto routingProfile = new osmscout::FastestPathRoutingProfile(database->GetTypeConfig());
    osmscout::TypeConfigRef typeConfig = database->GetTypeConfig();

    if (!outputGPX) {
        routerParameter.SetDebugPerformance(true);
    }

    auto router = new osmscout::RoutingService(database, routerParameter, g_vehicle);

    if (!router->Open()) {
        std::cerr << "Cannot open routing database" << std::endl;
        return false;
    }

    switch (g_vehicle) {
    case osmscout::vehicleFoot:
        routingProfile->ParametrizeForFoot(*typeConfig, 5.0);
        break;
    case osmscout::vehicleBicycle:
        routingProfile->ParametrizeForBicycle(*typeConfig, 20.0);
        break;
    case osmscout::vehicleCar:
        GetCarSpeedTable(carSpeedTable);
        routingProfile->ParametrizeForCar(*typeConfig, carSpeedTable, 160.0);
        break;
    }

    auto styleConfig = new osmscout::StyleConfig(database->GetTypeConfig());

    if (!styleConfig->Load(style)) {
        std::cerr << "Cannot open style" << std::endl;
        return false;
    }

    g_styleConfig = osmscout::StyleConfigRef(styleConfig);
    g_router = osmscout::RoutingServiceRef(router);
    g_routingProfile = osmscout::FastestPathRoutingProfileRef(routingProfile);
    return true;
}
// router->Close();

extern "C"
struct Point* createPoint(float lat, float lon) {
    osmscout::ObjectFileRef object;
    size_t nodeIndex;
    auto result = new Point;

    if (!g_router->GetClosestRoutableNode(lat, lon, g_vehicle, 1000, object, nodeIndex)) {
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
struct Itinerary* createItinerary(float startLat, float startLon,
                                  float targetLat, float targetLon) {
    struct Point* start = createPoint(startLat, startLon);
    struct Point* target = createPoint(targetLat, targetLon);
    auto way = new osmscout::Way;
    auto result = new Itinerary;
    osmscout::RouteData data;

    if (!g_router->CalculateRoute(*g_routingProfile, start->object, start->nodeIndex, target->object, target->nodeIndex, data)) {
        std::cerr << "There was an error while calculating the route!" << std::endl;
        return NULL;
    }

    if (data.IsEmpty()) {
        std::cout << "No Route found!" << std::endl;
        return NULL;
    }

    if (!g_router->TransformRouteDataToWay(data, *way)) {
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
bool paint(size_t x, size_t y,
           size_t width, size_t height,
           const Itinerary* itinerary,
           const osmscout::Magnification* magnification,
           cairo_t* cairo) {
    osmscout::TileProjection projection;
    osmscout::MapParameter drawParameter;
    osmscout::AreaSearchParameter searchParameter;
    Painter painter(g_styleConfig);

    osmscout::MapData data;

    drawParameter.SetFontSize(3.0);
    data.poiWays.push_back(itinerary->way);

    projection.Set(x, y, *magnification, DPI, width, height);

    return painter.DrawMap(projection, drawParameter, data, cairo);
}



#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <stdint.h>

extern "C"
value cairo_address(value v)
{
    return caml_copy_nativeint(*(intptr_t *)Data_custom_val(v));
}
