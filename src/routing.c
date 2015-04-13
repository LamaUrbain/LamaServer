#include <osmscout/Database.h>
#include <osmscout/MapService.h>

#include <osmscout/MapPainterCairo.h>

#include <osmscout/RoutingService.h>
#include <osmscout/POIService.h>
#include <osmscout/RoutePostprocessor.h>
#include <osmscout/util/Geometry.h>
#include <osmscout/util/Tiling.h>

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

const std::string map = "../../libosmscout/maps/picardie-latest";
const std::string style = "../../libosmscout/stylesheets/standard.oss";

extern "C"
struct Itinerary* createItinerary(float startLat, float startLon,
                                  float targetLat, float targetLon) {
    osmscout::Vehicle vehicle = osmscout::vehicleCar;

    osmscout::ObjectFileRef startObject;
    size_t startNodeIndex;

    osmscout::ObjectFileRef targetObject;
    size_t targetNodeIndex;

    bool outputGPX = false;

    osmscout::DatabaseParameter databaseParameter;
    osmscout::DatabaseRef       database(new osmscout::Database(databaseParameter));
    if (!database->Open(map.c_str())) {
        std::cerr << "Cannot open database" << std::endl;

        return NULL;
    }

    osmscout::FastestPathRoutingProfile routingProfile(database->GetTypeConfig());
    osmscout::RouterParameter           routerParameter;

    if (!outputGPX) {
        routerParameter.SetDebugPerformance(true);
    }

    osmscout::RoutingServiceRef router(new osmscout::RoutingService(database,
                                                                    routerParameter,
                                                                    vehicle));

    if (!router->Open()) {
        std::cerr << "Cannot open routing database" << std::endl;

        return NULL;
    }

    osmscout::TypeConfigRef             typeConfig=database->GetTypeConfig();
    osmscout::RouteData                 data;
    osmscout::RouteDescription          description;
    std::map<std::string,double>        carSpeedTable;

    switch (vehicle) {
    case osmscout::vehicleFoot:
        routingProfile.ParametrizeForFoot(*typeConfig, 5.0);
        break;
    case osmscout::vehicleBicycle:
        routingProfile.ParametrizeForBicycle(*typeConfig, 20.0);
        break;
    case osmscout::vehicleCar:
        GetCarSpeedTable(carSpeedTable);
        routingProfile.ParametrizeForCar(*typeConfig, carSpeedTable, 160.0);
        break;
    }

    if (!router->GetClosestRoutableNode(startLat,
                                        startLon,
                                        vehicle,
                                        1000,
                                        startObject,
                                        startNodeIndex)) {
        std::cerr << "Error while searching for routing node near start location!" << std::endl;
        return NULL;
    }

    if (startObject.Invalid() || startObject.GetType()==osmscout::refNode) {
        std::cerr << "Cannot find start node for start location!" << std::endl;
    }

    if (!router->GetClosestRoutableNode(targetLat,
                                        targetLon,
                                        vehicle,
                                        1000,
                                        targetObject,
                                        targetNodeIndex)) {
        std::cerr << "Error while searching for routing node near target location!" << std::endl;
        return NULL;
    }

    if (targetObject.Invalid() || targetObject.GetType()==osmscout::refNode) {
        std::cerr << "Cannot find start node for target location!" << std::endl;
    }

    if (!router->CalculateRoute(routingProfile,
                                startObject,
                                startNodeIndex,
                                targetObject,
                                targetNodeIndex,
                                data)) {
        std::cerr << "There was an error while calculating the route!" << std::endl;
        router->Close();
        return NULL;
    }

    if (data.IsEmpty()) {
        std::cout << "No Route found!" << std::endl;

        router->Close();

        return NULL;
    }

    auto way = new osmscout::Way;

    if (!router->TransformRouteDataToWay(data, *way)) {
        std::cerr << "Cannot transform route date to way" << std::endl;

        return NULL;
    }

    auto styleConfig = new osmscout::StyleConfig(database->GetTypeConfig());

    if (!styleConfig->Load(style)) {
        std::cerr << "Cannot open style" << std::endl;

        return NULL;
    }

    auto result = new Itinerary;

    result->way = osmscout::WayRef(way);
    result->styleConfig = osmscout::StyleConfigRef(styleConfig);

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
    Painter painter(itinerary->styleConfig);

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
