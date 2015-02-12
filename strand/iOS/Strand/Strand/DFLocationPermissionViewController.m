//
//  DFLocationPermissionViewController.m
//  Strand
//
//  Created by Henry Bridge on 2/12/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFLocationPermissionViewController.h"
#import "DFAnalytics.h"
#import "DFBackgroundLocationManager.h"
#import "DFSettings.h"

@interface DFLocationPermissionViewController()

@property (nonatomic) BOOL calledCompleted;
@property (nonatomic) BOOL showedLocationRequired;
@property (nonatomic) NSUInteger denyCount;

@end

@implementation DFLocationPermissionViewController
- (instancetype)init
{
  self = [super initWithTitle:@"Location Access"
                        image:[UIImage imageNamed:@"Assets/Nux/LocationAccessGraphic"]
              explanationText:@"Swap needs location access to suggest friends who were nearby when you took a photo"
                  buttonTitle:@"Grant Access"
          ];
  if (self) {
    
  }
  return self;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)buttonPressed:(id)sender {
  self.button.enabled = NO;
  [[DFBackgroundLocationManager sharedManager] promptForAuthorization:^(CLAuthorizationStatus resultStatus) {
    [self completedWithGranted:(resultStatus == kCLAuthorizationStatusAuthorizedAlways)];
  }];
}

- (void)completedWithGranted:(BOOL)granted
{
  if (!self.calledCompleted && granted) {
    self.calledCompleted = YES;
    [self completedWithUserInfo:nil];
    [DFAnalytics logSetupLocationCompletedWithResult:DFAnalyticsValueResultSuccess
                                           denyCount:self.denyCount];
  } else if (!granted) {
    self.denyCount++;
    self.button.enabled = YES;
    if (!self.showedLocationRequired) {
      [UIAlertView showSimpleAlertWithTitle:@"Location Required"
                                    message:@"Please grant location access to continue"];
      self.showedLocationRequired = YES;
    }
  }
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}
@end
