//
//  DFFirstTimeSetupViewController.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFFirstTimeSetupViewController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "DFAppDelegate.h"
#import "DFAnalytics.h"

@interface DFFirstTimeSetupViewController ()

@end

@implementation DFFirstTimeSetupViewController

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
    
    [self.activityIndicatorView startAnimating];
    
    DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
    [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID]
                     withSuccessBlock:^(DFUser *user) {
                         if (user) {
                             [[DFUser currentUser] setUserID:user.userID];
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 DFAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                                 [appDelegate showLoggedInUserTabs];
                             });
                         } else {
                             // the request succeeded, but the user doesn't exist, we have to create it
                             [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                                               withSuccessBlock:^(DFUser *user) {
                                                   [[DFUser currentUser] setUserID:user.userID];
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       DFAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                                                       [appDelegate showLoggedInUserTabs];
                                                   });
                                               }
                                                   failureBlock:^(NSError *error) {
                                                       [NSException raise:@"No user" format:@"Failed to get or create user for device ID."];
                                                   }];
                         }
                     } failureBlock:^(NSError *error) {
                         DFAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                         [appDelegate showLoggedInUserTabs];
                     }];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
