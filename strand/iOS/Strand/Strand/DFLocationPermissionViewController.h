//
//  DFLocationPermissionViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface DFLocationPermissionViewController : UIViewController <CLLocationManagerDelegate>

- (IBAction)learnMoreButtonPressed:(id)sender;
- (IBAction)grantLocationButtonPressed:(id)sender;

@end
