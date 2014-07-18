//
//  DFLocationRoadblockViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLocationRoadblockViewController.h"
#import "DFAnalytics.h"
#import "DFDefaultsStore.h"
#import "DFPermissionsHelpers.h"

@interface DFLocationRoadblockViewController ()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) NSTimer *timer;

@end

@implementation DFLocationRoadblockViewController

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
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated
{
  DDLogInfo(@"%@ appeared.", [self.class description]);
  [super viewDidAppear:animated];
  [self startLocationUpdates];
  self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                target:self
                                              selector:@selector(startLocationUpdates)
                                              userInfo:nil
                                               repeats:YES];
}

- (void)startLocationUpdates
{
  [self.locationManager stopUpdatingLocation];
  [self.locationManager startUpdatingLocation];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  [self.locationManager stopUpdatingLocation];
  DDLogInfo(@"%@ location succeeded.  Dismissing.", [self.class description]);
  [self.timer invalidate];
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  DDLogInfo(@"%@ location update failed.", [self.class description]);
}

- (CLLocationManager *)locationManager
{
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
  }
  return _locationManager;
}


@end

