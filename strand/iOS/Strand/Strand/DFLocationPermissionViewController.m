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
#import "RootViewController.h"

@interface DFLocationPermissionViewController ()

@property (nonatomic, readonly, retain) SAMGradientView *gradientView;
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
  
  self.gradientView.gradientColors = @[[UIColor orangeColor], [DFStrandConstants strandOrange]];
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
  [self.locationManager startUpdatingLocation];
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
  [DFAnalytics logSetupLocationCompletedWithResult:DFAnalyticsValueResultFailure
                               userTappedLearnMore:self.didShowLearnMore];
  DFPermissionStateType newState;
  if (error.code == kCLErrorDenied) {
    newState = DFPermissionStateDenied;
  } else {
    newState = DFPermissionStateUnavailable;
  }
  [DFAnalytics logPermission:DFPermissionLocation changedWithOldState:nil newState:newState];
  [DFDefaultsStore setState:newState forPermission:DFPermissionLocation];
  
  [self.locationManager stopUpdatingLocation];
  [self dismiss];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  [DFAnalytics logSetupLocationCompletedWithResult:DFAnalyticsValueResultSuccess
                               userTappedLearnMore:self.didShowLearnMore];
  [DFAnalytics logPermission:DFPermissionLocation changedWithOldState:nil newState:DFPermissionStateGranted];
  [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionLocation];
  [self.locationManager stopUpdatingLocation];
  [self dismiss];
}

- (void)dismiss
{
  AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
  [delegate showMainView];
  dispatch_async(dispatch_get_main_queue(), ^{
    [(RootViewController *)delegate.window.rootViewController showGallery];
  });
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}


@end
