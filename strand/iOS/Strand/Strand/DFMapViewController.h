//
//  DFMapViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CLLocation;
@class MKMapView;

@interface DFMapViewController : UIViewController

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) CLLocation *location;

- (instancetype)initWithLocation:(CLLocation *)location;

@end
