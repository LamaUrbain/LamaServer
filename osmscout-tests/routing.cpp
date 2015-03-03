#include <osmscout/Database.h>
#include <osmscout/MapService.h>

#include <osmscout/MapPainterCairo.h>

#include <osmscout/RoutingService.h>
#include <osmscout/POIService.h>
#include <osmscout/RoutePostprocessor.h>
#include <osmscout/util/Geometry.h>

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

int main(int argc, char* argv[]) {
    osmscout::Vehicle                         vehicle=osmscout::vehicleCar;
    std::string                               map;

    double                                    startLat;
    double                                    startLon;

    double                                    targetLat;
    double                                    targetLon;

    osmscout::ObjectFileRef                   startObject;
    size_t                                    startNodeIndex;

    osmscout::ObjectFileRef                   targetObject;
    size_t                                    targetNodeIndex;

    bool                                      outputGPX = false;

    std::string   style;
    std::string   output;
    size_t        width,height;
    double        zoom;

    if (argc!=11) {
        std::cerr << "DrawMap <map directory> <style-file> <width> <height> <start lon> <start lat> <target lon> <target lat> <zoom> <output>" << std::endl;
        return 1;
    }

    map=argv[1];
    style=argv[2];

    if (!osmscout::StringToNumber(argv[3],width)) {
        std::cerr << "width is not numeric!" << std::endl;
        return 1;
    }

    if (!osmscout::StringToNumber(argv[4],height)) {
        std::cerr << "height is not numeric!" << std::endl;
        return 1;
    }

    if (sscanf(argv[5],"%lf",&startLon)!=1) {
        std::cerr << "Start lon is not numeric!" << std::endl;
        return 1;
    }

    if (sscanf(argv[6],"%lf",&startLat)!=1) {
        std::cerr << "Start lat is not numeric!" << std::endl;
        return 1;
    }

    if (sscanf(argv[7],"%lf",&targetLon)!=1) {
        std::cerr << "Target lon is not numeric!" << std::endl;
        return 1;
    }

    if (sscanf(argv[8],"%lf",&targetLat)!=1) {
        std::cerr << "Target lat is not numeric!" << std::endl;
        return 1;
    }

    if (sscanf(argv[9],"%lf",&zoom)!=1) {
        std::cerr << "zoom is not numeric!" << std::endl;
        return 1;
    }

    output=argv[10];

    osmscout::DatabaseParameter databaseParameter;
    osmscout::DatabaseRef       database(new osmscout::Database(databaseParameter));
    if (!database->Open(map.c_str())) {
        std::cerr << "Cannot open database" << std::endl;

        return 1;
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

        return 1;
    }

    osmscout::TypeConfigRef             typeConfig=database->GetTypeConfig();
    osmscout::RouteData                 data;
    osmscout::RouteDescription          description;
    std::map<std::string,double>        carSpeedTable;

    switch (vehicle) {
    case osmscout::vehicleFoot:
        routingProfile.ParametrizeForFoot(*typeConfig,
                                          5.0);
        break;
    case osmscout::vehicleBicycle:
        routingProfile.ParametrizeForBicycle(*typeConfig,
                                             20.0);
        break;
    case osmscout::vehicleCar:
        GetCarSpeedTable(carSpeedTable);
        routingProfile.ParametrizeForCar(*typeConfig,
                                         carSpeedTable,
                                         160.0);
        break;
    }

    if (!router->GetClosestRoutableNode(startLat,
                                        startLon,
                                        vehicle,
                                        1000,
                                        startObject,
                                        startNodeIndex)) {
        std::cerr << "Error while searching for routing node near start location!" << std::endl;
        return 1;
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
        return 1;
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
        return 1;
    }

    if (data.IsEmpty()) {
        std::cout << "No Route found!" << std::endl;

        router->Close();

        return 0;
    }

    osmscout::MapServiceRef     mapService(new osmscout::MapService(database));

    osmscout::StyleConfigRef styleConfig(new osmscout::StyleConfig(database->GetTypeConfig()));

    if (!styleConfig->Load(style)) {
        std::cerr << "Cannot open style" << std::endl;
    }
    /*
    osmscout::POIServiceRef     poiService(new osmscout::POIService(database));

    osmscout::TypeSet                nodeTypes(*typeConfig);
    osmscout::TypeSet                wayTypes(*typeConfig);
    osmscout::TypeSet                areaTypes(*typeConfig);

    std::vector<osmscout::NodeRef> nodes;
    std::vector<osmscout::WayRef>  ways;
    std::vector<osmscout::AreaRef> areas;

    if (!poiService->GetPOIsInArea(std::min(startLon,targetLon),
                                   std::min(startLat,targetLat),
                                   std::max(startLon,targetLon),
                                   std::max(startLon,targetLat),
                                   nodeTypes,
                                   nodes,
                                   wayTypes,
                                   ways,
                                   areaTypes,
                                   areas)) {
        std::cerr << "Cannot load data from database" << std::endl;

        return 1;
    }

    std::cout << ways.size() << std::endl;
    */
    osmscout::Way way_raw;

    if(!router->TransformRouteDataToWay(data, way_raw)) {
        std::cerr << "LOL" << std::endl;
        return 1;

    }

    osmscout::WayRef way(new osmscout::Way(way_raw));

    cairo_surface_t *surface;
    cairo_t         *cairo;

    surface=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,width,height);

    if (surface!=NULL) {
        cairo=cairo_create(surface);

        if (cairo!=NULL) {
            cairo_set_source_rgba(cairo, 0, 0, 0, 0);
            cairo_fill(cairo);

            osmscout::MercatorProjection  projection;
            osmscout::MapParameter        drawParameter;
            osmscout::AreaSearchParameter searchParameter;
            osmscout::MapData             data;
            Painter     painter(styleConfig);

            drawParameter.SetFontSize(3.0);

            projection.Set(startLon,
                           startLat,
                           osmscout::Magnification(zoom),
                           DPI,
                           width,
                           height);
            /*
            mapService->GetObjects(searchParameter,
                                   styleConfig,
                                   projection,
                                   data);
            */
/*            data.poiWays = std::list<osmscout::WayRef>(ways.begin(), ways.end());
            data.poiNodes = std::list<osmscout::NodeRef>(nodes.begin(), nodes.end());
            data.poiAreas = std::list<osmscout::AreaRef>(areas.begin(), areas.end());
*/

            data.poiWays.push_back(way);

            if (painter.DrawMap(projection,
                                drawParameter,
                                data,
                                cairo)) {
                if (cairo_surface_write_to_png(surface,output.c_str())!=CAIRO_STATUS_SUCCESS) {
                    std::cerr << "Cannot write PNG" << std::endl;
                }
            }

            cairo_destroy(cairo);
        }
        else {
            std::cerr << "Cannot create cairo cairo" << std::endl;
        }

        cairo_surface_destroy(surface);
    }
    else {
        std::cerr << "Cannot create cairo surface" << std::endl;
    }

    return 0;
}
