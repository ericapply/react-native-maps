//
//  AIRGoogleMapManager.h
//  AirMaps
//
//  Created by Gil Birman on 9/1/16.
//

#import <React/RCTViewManager.h>
#import <GoogleMaps/GoogleMaps.h>

@interface AIRGoogleMapManager : RCTViewManager

@property (nonatomic, strong) GMSMapView *map;

@end
