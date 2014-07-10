//
//  DFMapViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFMapViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

MKCoordinateSpan const defaultSpan = (MKCoordinateSpan){.01,.01};

@interface DFMapAnnotation : NSObject <MKAnnotation>

@property (nonatomic, retain) NSString *savedTitle;
@property (nonatomic, retain) NSString *savedSubTitle;
@property (nonatomic) CLLocationCoordinate2D savedCoordinate;

@end

@implementation DFMapAnnotation

- (NSString *)title {
  return [self.savedTitle copy];
}

- (void)setTitle:(NSString *)title{
  self.savedTitle = [title copy];
}

- (NSString *)subTitle
{
  return self.savedSubTitle;
}

- (CLLocationCoordinate2D)coordinate {
  return self.savedCoordinate;
}


@end

@interface DFMapViewController ()
@property (nonatomic, retain) DFMapAnnotation *lastLocationMapAnnotation;
@end

@implementation DFMapViewController

- (instancetype)initWithLocation:(CLLocation *)location
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _location = location;
  }
  return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

// pad our map by 10% around the farthest annotations
#define MAP_PADDING 1.1

// we'll make sure that our minimum vertical span is about a kilometer
// there are ~111km to a degree of latitude. regionThatFits will take care of
// longitude, which is more complicated, anyway.
#define MINIMUM_VISIBLE_LATITUDE 0.01


- (MKCoordinateRegion)regionForCurrentAndLastPoint
{
  CLLocationDegrees minLatitude = fmin(self.location.coordinate.latitude,
                                       self.mapView.userLocation.coordinate.latitude);
  CLLocationDegrees maxLatitude = fmax(self.location.coordinate.latitude,
                                       self.mapView.userLocation.coordinate.latitude);
  CLLocationDegrees minLongitude = fmin(self.location.coordinate.longitude,
                                        self.mapView.userLocation.coordinate.longitude);
  CLLocationDegrees maxLongitude = fmax(self.location.coordinate.longitude,
                                        self.mapView.userLocation.coordinate.longitude);
  
  MKCoordinateRegion region;
  region.center.latitude = (minLatitude + maxLatitude) / 2;
  region.center.longitude = (minLongitude + maxLongitude) / 2;
  
  region.span.latitudeDelta = (maxLatitude - minLatitude) * MAP_PADDING;
  
  region.span.latitudeDelta = (region.span.latitudeDelta < MINIMUM_VISIBLE_LATITUDE)
  ? MINIMUM_VISIBLE_LATITUDE
  : region.span.latitudeDelta;
  
  region.span.longitudeDelta = (maxLongitude - minLongitude) * MAP_PADDING;
  
  MKCoordinateRegion scaledRegion = [self.mapView regionThatFits:region];
  return scaledRegion;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.mapView.centerCoordinate = self.location.coordinate;
  self.mapView.region = MKCoordinateRegionMake(self.location.coordinate, defaultSpan);
  self.mapView.showsUserLocation = YES;
  
  [self.mapView addAnnotation:self.lastLocationMapAnnotation];
  [self.mapView selectAnnotation:self.lastLocationMapAnnotation animated:NO];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (DFMapAnnotation *)lastLocationMapAnnotation
{
  if (!_lastLocationMapAnnotation) {
    _lastLocationMapAnnotation = [[DFMapAnnotation alloc] init];
    _lastLocationMapAnnotation.savedTitle = @"Last Location";
    _lastLocationMapAnnotation.savedSubTitle = @"According to background manager";
    _lastLocationMapAnnotation.savedCoordinate = self.location.coordinate;
  }
  
  return _lastLocationMapAnnotation;
}

@end
