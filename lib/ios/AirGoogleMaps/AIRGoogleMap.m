//
//  AIRGoogleMap.m
//  AirMaps
//
//  Created by Gil Birman on 9/1/16.
//

#import "AIRGoogleMap.h"
#import "AIRGoogleMapMarker.h"
#import "AIRGoogleMapPolygon.h"
#import "AIRGoogleMapPolyline.h"
#import "AIRGoogleMapCircle.h"
#import "AIRGoogleMapUrlTile.h"
#import <Google-Maps-iOS-Utils/GMUMarkerClustering.h>
#import <GoogleMaps/GoogleMaps.h>
#import <MapKit/MapKit.h>
#import <React/UIView+React.h>
#import "RCTConvert+AirMap.h"
#import "GMUGridBasedClusterAlgorithm.h"
#import "GMUNonHierarchicalDistanceBasedAlgorithm.h"
#import "GMUClusterManager.h"
#import "GMUDefaultClusterIconGenerator.h"
#import "GMUDefaultClusterRenderer.h"
#import "GMUStaticCluster.h"
#import "GlobalVars.h"

@interface ClusterRenderer : GMUDefaultClusterRenderer
@end

@implementation ClusterRenderer

- (BOOL)shouldRenderAsCluster:(id<GMUCluster>)cluster atZoom:(float)zoom {

  // If zoom level is greater than 16, don't cluster markers
  if(zoom > 16) {
    return NO;
  }
  
  return cluster.count > 1;
}

@end

id regionAsJSON(MKCoordinateRegion region) {
  return @{
           @"latitude": [NSNumber numberWithDouble:region.center.latitude],
           @"longitude": [NSNumber numberWithDouble:region.center.longitude],
           @"latitudeDelta": [NSNumber numberWithDouble:region.span.latitudeDelta],
           @"longitudeDelta": [NSNumber numberWithDouble:region.span.longitudeDelta],
           };
}

@interface AIRGoogleMap ()<GMUClusterRendererDelegate>

- (id)eventFromCoordinate:(CLLocationCoordinate2D)coordinate;

@end

@implementation AIRGoogleMap
{
  NSMutableArray<UIView *> *_reactSubviews;
  BOOL _initialRegionSet;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _reactSubviews = [NSMutableArray new];
    _markers = [NSMutableArray array];
    _polygons = [NSMutableArray array];
    _polylines = [NSMutableArray array];
    _circles = [NSMutableArray array];
    _tiles = [NSMutableArray array];
    _initialRegionSet = false;
    
    // Init native google maps clustering
    id<GMUClusterAlgorithm> algorithm = [[GMUNonHierarchicalDistanceBasedAlgorithm alloc] init];
    id<GMUClusterIconGenerator> iconGenerator = [[GMUDefaultClusterIconGenerator alloc] init];
    
    ClusterRenderer *renderer = [[ClusterRenderer alloc] initWithMapView:self clusterIconGenerator:iconGenerator];
    renderer.delegate = self;
    
    self.clusterManager = [[GMUClusterManager alloc] initWithMap:self algorithm:algorithm renderer:renderer];
  }
  
  return self;
}
- (id)eventFromCoordinate:(CLLocationCoordinate2D)coordinate {

  CGPoint touchPoint = [self.projection pointForCoordinate:coordinate];

  return @{
           @"coordinate": @{
               @"latitude": @(coordinate.latitude),
               @"longitude": @(coordinate.longitude),
               },
           @"position": @{
               @"x": @(touchPoint.x),
               @"y": @(touchPoint.y),
               },
           };
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)insertReactSubview:(id<RCTComponent>)subview atIndex:(NSInteger)atIndex {
  // Our desired API is to pass up markers/overlays as children to the mapview component.
  // This is where we intercept them and do the appropriate underlying mapview action.
  if ([subview isKindOfClass:[AIRGoogleMapMarker class]]) {
    AIRGoogleMapMarker *marker = (AIRGoogleMapMarker*)subview;
    if(marker.cluster) {
      [self.clusterManager addItem:marker];
    } else {
      marker.realMarker.map = self;
      [self.markers addObject:marker];
    }
    marker.clusterManager = self.clusterManager;
  } else if ([subview isKindOfClass:[AIRGoogleMapPolygon class]]) {
    AIRGoogleMapPolygon *polygon = (AIRGoogleMapPolygon*)subview;
    polygon.polygon.map = self;
    [self.polygons addObject:polygon];
  } else if ([subview isKindOfClass:[AIRGoogleMapPolyline class]]) {
    AIRGoogleMapPolyline *polyline = (AIRGoogleMapPolyline*)subview;
    polyline.polyline.map = self;
    [self.polylines addObject:polyline];
  } else if ([subview isKindOfClass:[AIRGoogleMapCircle class]]) {
    AIRGoogleMapCircle *circle = (AIRGoogleMapCircle*)subview;
    circle.circle.map = self;
    [self.circles addObject:circle];
  } else if ([subview isKindOfClass:[AIRGoogleMapUrlTile class]]) {
    AIRGoogleMapUrlTile *tile = (AIRGoogleMapUrlTile*)subview;
    tile.tileLayer.map = self;
    [self.tiles addObject:tile];
  } else {
    NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
    for (int i = 0; i < childSubviews.count; i++) {
      [self insertReactSubview:(UIView *)childSubviews[i] atIndex:atIndex];
    }
  }
  [_reactSubviews insertObject:(UIView *)subview atIndex:(NSUInteger) atIndex];
}
#pragma clang diagnostic pop


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)removeReactSubview:(id<RCTComponent>)subview {
  // similarly, when the children are being removed we have to do the appropriate
  // underlying mapview action here.
  if ([subview isKindOfClass:[AIRGoogleMapMarker class]]) {
    AIRGoogleMapMarker *marker = (AIRGoogleMapMarker*)subview;
    if(marker.cluster) {
      [self.clusterManager removeItem:marker];
    } else {
      marker.realMarker.map = nil;
      [self.markers removeObject:marker];
    }
  } else if ([subview isKindOfClass:[AIRGoogleMapPolygon class]]) {
    AIRGoogleMapPolygon *polygon = (AIRGoogleMapPolygon*)subview;
    polygon.polygon.map = nil;
    [self.polygons removeObject:polygon];
  } else if ([subview isKindOfClass:[AIRGoogleMapPolyline class]]) {
    AIRGoogleMapPolyline *polyline = (AIRGoogleMapPolyline*)subview;
    polyline.polyline.map = nil;
    [self.polylines removeObject:polyline];
  } else if ([subview isKindOfClass:[AIRGoogleMapCircle class]]) {
    AIRGoogleMapCircle *circle = (AIRGoogleMapCircle*)subview;
    circle.circle.map = nil;
    [self.circles removeObject:circle];
  } else if ([subview isKindOfClass:[AIRGoogleMapUrlTile class]]) {
    AIRGoogleMapUrlTile *tile = (AIRGoogleMapUrlTile*)subview;
    tile.tileLayer.map = nil;
    [self.tiles removeObject:tile];
  } else {
    NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
    for (int i = 0; i < childSubviews.count; i++) {
      [self removeReactSubview:(UIView *)childSubviews[i]];
    }
  }
  [_reactSubviews removeObject:(UIView *)subview];
}
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (NSArray<id<RCTComponent>> *)reactSubviews {
  return _reactSubviews;
}
#pragma clang diagnostic pop

- (void)setInitialRegion:(MKCoordinateRegion)initialRegion {
  if (_initialRegionSet) return;
  _initialRegionSet = true;
  self.camera = [AIRGoogleMap makeGMSCameraPositionFromMap:self andMKCoordinateRegion:initialRegion];
}

- (void)setRegion:(MKCoordinateRegion)region {
  // TODO: The JS component is repeatedly setting region unnecessarily. We might want to deal with that in here.
  self.camera = [AIRGoogleMap makeGMSCameraPositionFromMap:self  andMKCoordinateRegion:region];
}

- (BOOL)didTapMarker:(GMSMarker *)marker {
  AIRGMSMarker *airMarker = (AIRGMSMarker *)marker;

  AIRGoogleMapMarker *clusterMarker = (AIRGoogleMapMarker *)airMarker.userData;
  if(clusterMarker != nil) {
    id markerPressEvent;
    
    if([clusterMarker respondsToSelector:@selector(identifier)]) {
      markerPressEvent = @{
                           @"action": @"marker-press",
                           @"cluster": @(YES),
                           @"count": @(1),
                           @"id": clusterMarker.identifier,
                           @"coordinate": @{
                             @"latitude": @(clusterMarker.position.latitude),
                             @"longitude": @(clusterMarker.position.longitude)
                           }
                         };
    } else {
      GMUStaticCluster *clusteredMarker = (GMUStaticCluster *)clusterMarker;
      // Marker is a clustered marker
      
      // 1. Zoom into clustered marker
      // [self animateToCameraPosition:[GMSCameraPosition cameraWithTarget:clusteredMarker.position zoom:self.camera.zoom +2]];
      
      // 2. Send press event to JS
      markerPressEvent = @{
                           @"action": @"marker-press",
                           @"cluster": @(YES),
                           @"count": @(clusteredMarker.items.count),
                           @"coordinate": @{
                             @"latitude": @(clusteredMarker.position.latitude),
                             @"longitude": @(clusteredMarker.position.longitude)
                           }
                         };
    }

    self.onPress(markerPressEvent);
    return NO;
  } else {
    
    id event = @{@"action": @"marker-press",
                 @"cluster": @(NO),
                 @"count": @(1),
                 @"id": airMarker.identifier,
                 @"coordinate": @{
                     @"latitude": @(airMarker.position.latitude),
                     @"longitude": @(airMarker.position.longitude)
                 }
               };
  
    if (airMarker.onPress) airMarker.onPress(event);
    if (self.onMarkerPress) self.onMarkerPress(event);
    
    // TODO: not sure why this is necessary
    if(self.selectedMarker) [self setSelectedMarker:marker];
    return NO;
  }
}

- (void)didTapPolygon:(GMSOverlay *)polygon {
    AIRGMSPolygon *airPolygon = (AIRGMSPolygon *)polygon;

    id event = @{@"action": @"polygon-press",
                 @"id": airPolygon.identifier ?: @"unknown",
                 };

    if (airPolygon.onPress) airPolygon.onPress(event);
}

- (void)didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  if (!self.onPress) return;
  self.onPress([self eventFromCoordinate:coordinate]);
}

- (void)didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate {
  if (!self.onLongPress) return;
  self.onLongPress([self eventFromCoordinate:coordinate]);
}

- (void)didChangeCameraPosition:(GMSCameraPosition *)position {
  id event = @{@"continuous": @YES,
               @"region": regionAsJSON([AIRGoogleMap makeGMSCameraPositionFromMap:self andGMSCameraPosition:position]),
               };

  if (self.onChange) self.onChange(event);
}

- (void)idleAtCameraPosition:(GMSCameraPosition *)position {
  id event = @{@"continuous": @NO,
               @"region": regionAsJSON([AIRGoogleMap makeGMSCameraPositionFromMap:self andGMSCameraPosition:position]),
               };
  if (self.onChange) self.onChange(event);  // complete
}


- (void)setScrollEnabled:(BOOL)scrollEnabled {
  self.settings.scrollGestures = scrollEnabled;
}

- (BOOL)scrollEnabled {
  return self.settings.scrollGestures;
}

- (void)setZoomEnabled:(BOOL)zoomEnabled {
  self.settings.zoomGestures = zoomEnabled;
}

- (BOOL)zoomEnabled {
  return self.settings.zoomGestures;
}

- (void)setRotateEnabled:(BOOL)rotateEnabled {
  self.settings.rotateGestures = rotateEnabled;
}

- (BOOL)rotateEnabled {
  return self.settings.rotateGestures;
}

- (void)setPitchEnabled:(BOOL)pitchEnabled {
  self.settings.tiltGestures = pitchEnabled;
}

- (BOOL)pitchEnabled {
  return self.settings.tiltGestures;
}

- (void)setShowsTraffic:(BOOL)showsTraffic {
  self.trafficEnabled = showsTraffic;
}

- (BOOL)showsTraffic {
  return self.trafficEnabled;
}

- (void)setShowsBuildings:(BOOL)showsBuildings {
  self.buildingsEnabled = showsBuildings;
}

- (BOOL)showsBuildings {
  return self.buildingsEnabled;
}

- (void)setShowsCompass:(BOOL)showsCompass {
  self.settings.compassButton = showsCompass;
}

- (void)setCustomMapStyleString:(NSString *)customMapStyleString {
  NSError *error;

  GMSMapStyle *style = [GMSMapStyle styleWithJSONString:customMapStyleString error:&error];

  if (!style) {
    NSLog(@"The style definition could not be loaded: %@", error);
  }

  self.mapStyle = style;
}

- (BOOL)showsCompass {
  return self.settings.compassButton;
}

- (void)setShowsUserLocation:(BOOL)showsUserLocation {
  self.myLocationEnabled = showsUserLocation;
}

- (BOOL)showsUserLocation {
  return self.myLocationEnabled;
}

- (void)setShowsMyLocationButton:(BOOL)showsMyLocationButton {
  self.settings.myLocationButton = showsMyLocationButton;
}

- (BOOL)showsMyLocationButton {
  return self.settings.myLocationButton;
}

- (void)renderer:(id<GMUClusterRenderer>)renderer willRenderMarker:(GMSMarker *)marker {
  // Center the marker at the bottom of the image.
  marker.groundAnchor = CGPointMake(0.5, 1.0);
  if ([marker.userData isKindOfClass:[AIRGoogleMapMarker class]]) {
    AIRGoogleMapMarker *annotation = (AIRGoogleMapMarker *)marker.userData;
    marker.icon = annotation.realMarker.icon;
  } else if ([marker.userData conformsToProtocol:@protocol(GMUCluster)]) {
    marker.icon = [self imageForCluster:marker.userData];
  }
}

- (UIImage *)imageForCluster:(id<GMUCluster>)cluster {
  
  NSUInteger clusterSize = cluster.items.count;
  
  NSString *clusterSizeString;
  if(clusterSize<=10) {
    clusterSizeString =[NSString stringWithFormat:@"%lu", (unsigned long)clusterSize];
  } else if(clusterSize <= 99){
    clusterSizeString = @"10+";
  } else {
    clusterSizeString = @"99+";
  }
  NSString *key = [NSString stringWithFormat:@"bubble%@", clusterSizeString];
  UIImage *cachedImage = [[GlobalVars sharedInstance] getSharedUIImageWithKey:key];
  
  if(cachedImage == nil) {
    // Load UIImage
    UIView *textBubbleView = [[[NSBundle mainBundle] loadNibNamed:@"textBubble" owner:self options:nil] objectAtIndex:0];
    UILabel *bubbleLabel =  (UILabel*)[textBubbleView viewWithTag:1];
    bubbleLabel.text = clusterSizeString;
    
    UIImage *bubbleLabelImage = [self imageWithView:textBubbleView];
    UIImage *markerImage = ((AIRGoogleMapMarker *)cluster.items.firstObject).realMarker.icon;
    
    cachedImage = [self imageByCombiningImage:markerImage withImage:bubbleLabelImage left:13 top:13];
    
    [[GlobalVars sharedInstance] setSharedUIImageWithKey:key withUIImage:cachedImage];
  }
  return cachedImage;
}

- (UIImage*)imageByCombiningImage:(UIImage*)firstImage withImage:(UIImage*)secondImage left:(float)left top:(float)top {
  UIImage *image = nil;
  
  int width = firstImage.size.width + secondImage.size.width;
  int height = firstImage.size.height + secondImage.size.height;
  CGSize newImageSize = CGSizeMake(width, height);
  
  UIGraphicsBeginImageContextWithOptions(newImageSize, NO, [[UIScreen mainScreen] scale]);
  [firstImage drawAtPoint:CGPointMake(0, top)];
  [secondImage drawAtPoint:CGPointMake(left, 0)];
  
  image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return image;
}

- (UIImage *) imageWithView:(UIView *)view
{
  UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
  [view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
  
  UIGraphicsEndImageContext();
  
  return img;
}

+ (MKCoordinateRegion) makeGMSCameraPositionFromMap:(GMSMapView *)map andGMSCameraPosition:(GMSCameraPosition *)position {
  // solution from here: http://stackoverflow.com/a/16587735/1102215
  GMSVisibleRegion visibleRegion = map.projection.visibleRegion;
  GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithRegion: visibleRegion];
  CLLocationCoordinate2D center;
  CLLocationDegrees longitudeDelta;
  CLLocationDegrees latitudeDelta = bounds.northEast.latitude - bounds.southWest.latitude;

  if(bounds.northEast.longitude >= bounds.southWest.longitude) {
    //Standard case
    center = CLLocationCoordinate2DMake((bounds.southWest.latitude + bounds.northEast.latitude) / 2,
                                        (bounds.southWest.longitude + bounds.northEast.longitude) / 2);
    longitudeDelta = bounds.northEast.longitude - bounds.southWest.longitude;
  } else {
    //Region spans the international dateline
    center = CLLocationCoordinate2DMake((bounds.southWest.latitude + bounds.northEast.latitude) / 2,
                                        (bounds.southWest.longitude + bounds.northEast.longitude + 360) / 2);
    longitudeDelta = bounds.northEast.longitude + 360 - bounds.southWest.longitude;
  }
  MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
  return MKCoordinateRegionMake(center, span);
}

+ (GMSCameraPosition*) makeGMSCameraPositionFromMap:(GMSMapView *)map andMKCoordinateRegion:(MKCoordinateRegion)region {
  float latitudeDelta = region.span.latitudeDelta * 0.5;
  float longitudeDelta = region.span.longitudeDelta * 0.5;

  CLLocationCoordinate2D a = CLLocationCoordinate2DMake(region.center.latitude + latitudeDelta,
                                                        region.center.longitude + longitudeDelta);
  CLLocationCoordinate2D b = CLLocationCoordinate2DMake(region.center.latitude - latitudeDelta,
                                                        region.center.longitude - longitudeDelta);
  GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:a coordinate:b];
  return [map cameraForBounds:bounds insets:UIEdgeInsetsZero];
}

//- (BOOL)clusterManager:(GMUClusterManager *)clusterManager didTapCluster:(id<GMUCluster>)cluster {
////  if (!self.onPress) return;
//  id event = @{@"action": @"cluster-marker-press",
//               @"items": cluster.items ?: nil,
//               };
//  
//  if (self.onClusterMarkerPress) self.onClusterMarkerPress(event);
//
//  return NO;
//  
//}

@end
