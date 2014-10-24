//
//  DFLocationPermissionViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLocationPermissionViewController.h"
#import "SAMGradientView.h"
#import "DFStrandConstants.h"
#import "MMPopLabel.h"
#import "UIAlertView+DFHelpers.h"
#import "AppDelegate.h"
#import "DFAnalytics.h"
#import "DFDefaultsStore.h"
#import "DFNavigationController.h"

@interface DFLocationPermissionViewController ()

@property (nonatomic, retain) MMPopLabel *learnMorePopLabel;
@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic) BOOL didShowLearnMore;

@end

@implementation DFLocationPermissionViewController

@synthesize locationManager = _locationManager;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view from its nib.
  SAMGradientView *gradientView = (SAMGradientView *)self.view;
  gradientView.gradientColors = @[[DFStrandConstants defaultBackgroundColor], [DFStrandConstants strandOrange]];
  [self configurePopLabel];
  [self.navigationController setNavigationBarHidden:YES];
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)configurePopLabel
{
  // create the labels
  self.learnMorePopLabel = [MMPopLabel popLabelWithText:
                            @"Strand uses location services to find friends near you. "
                            "When you take a photo in the app, nearby friends are notified and can see them."];
  self.learnMorePopLabel.labelColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
  self.learnMorePopLabel.labelTextColor = [UIColor whiteColor];
  self.learnMorePopLabel.labelFont = [UIFont systemFontOfSize:14];
  
  // add add them to the view
  [self.view addSubview:self.learnMorePopLabel];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (SAMGradientView *)gradientView
{
  return (SAMGradientView *)self.view;
}

- (IBAction)learnMoreButtonPressed:(id)sender {
  if (self.learnMorePopLabel.isHidden) {
    [self.learnMorePopLabel popAtView:sender animatePopLabel:YES animateTargetView:NO];
  } else {
    [self.learnMorePopLabel dismiss];
  }
  self.didShowLearnMore = YES;
}

- (IBAction)grantLocationButtonPressed:(id)sender {
  if (![CLLocationManager locationServicesEnabled]) {
    [UIAlertView showSimpleAlertWithTitle:@"Location Services Disabled"
                                  message:@"Location services are disabled. "
     "Please go to your Settings app and turn on location services."];
    return;
  }
  
  self.locationManager.delegate = self;
  self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
  if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
    // iOS 8 method, the actual text displayed is kept in Info.plist
    [self.locationManager requestAlwaysAuthorization];
  } else {
    // iOS 7 method
    [self.locationManager startUpdatingLocation];
  }
}


- (CLLocationManager *)locationManager
{
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
  }
  
  return _locationManager;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  if (error.code == kCLErrorDenied) {
    [self locationManager:manager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
  } else {
    // we should probably figure out something finer grained than this, but it suffices for now
    [self locationManager:manager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
  }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  // in iOS7, locationManager didChangeAuthorizationStatus doesn't exist, so we rely on a
  // successful location fetch to indicate that the authorization was granted
  [self locationManager:manager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
  DFPermissionStateType dfPermissionState;
  NSString *analyticsResult;
  
  if (status == kCLAuthorizationStatusNotDetermined) {
    // as soon as you request access, iOS 8 calls back with this
    // return immediately since we don't have the results yet
    return;
  } else if (status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedAlways) {
    analyticsResult = DFAnalyticsValueResultSuccess;
    dfPermissionState = DFPermissionStateGranted;
  } else if (status == kCLAuthorizationStatusDenied) {
    analyticsResult = DFAnalyticsValueResultFailure;
    dfPermissionState = DFPermissionStateDenied;
  } else if (status == kCLAuthorizationStatusRestricted) {
    analyticsResult = DFAnalyticsValueResultFailure;
    dfPermissionState = DFPermissionStateRestricted;
  }
  
  [DFAnalytics logSetupLocationCompletedWithResult:analyticsResult
                               userTappedLearnMore:self.didShowLearnMore];
  [DFAnalytics logPermission:DFPermissionLocation changedWithOldState:nil newState:dfPermissionState];
  [DFDefaultsStore setState:dfPermissionState forPermission:DFPermissionLocation];

  [self.locationManager stopUpdatingLocation];
  [self dismiss];
}

- (void)dismiss
{
  AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
  [delegate firstTimeSetupComplete];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}


@end
