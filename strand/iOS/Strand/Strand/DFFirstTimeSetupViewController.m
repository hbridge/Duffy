//
//  DFFirstTimeSetupViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFirstTimeSetupViewController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "AppDelegate.h"

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
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self getUserID];
}

- (void)getUserID
{
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID]
                   withSuccessBlock:^(DFUser *user) {
                     if (user) {
                       [[DFUser currentUser] setUserID:user.userID];
                       AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
                       [delegate showMainView];
                     } else {
                       // the request succeeded, but the user doesn't exist, we have to create it
                       [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                                               deviceName:[[DFUser currentUser] deviceName]
                                         withSuccessBlock:^(DFUser *user) {
                                           [[DFUser currentUser] setUserID:user.userID];
                                           AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
                                           [delegate showMainView];
                                         }
                                             failureBlock:^(NSError *error) {
                                               DDLogWarn(@"Create user failed: %@", error.localizedDescription);
                                               self.statusLabel.text = [NSString stringWithFormat:@"Create failed: %@", error.localizedDescription];
                                             }];
                     }
                   } failureBlock:^(NSError *error) {
                     DDLogWarn(@"Get user failed: %@", error.localizedDescription);
                     self.statusLabel.text = [NSString stringWithFormat:@"Get failed: %@", error.localizedDescription];
                   }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
