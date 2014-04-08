//
//  DFFirstTimeSetupViewController.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFFirstTimeSetupViewController.h"
#import "DFUserIDFetcher.h"
#import "DFUser.h"
#import "DFAppDelegate.h"

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
    
    DFUserIDFetcher *uidFetcher = [[DFUserIDFetcher alloc] init];
    [uidFetcher fetchUserInfoForDeviceID:[[DFUser currentUser] deviceID] withCompletionBlock:^(DFUser *user) {
        sleep(1);
        [[DFUser currentUser] setUserID:user.userID];
        dispatch_async(dispatch_get_main_queue(), ^{
            DFAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [appDelegate showLoggedInUserTabs];
        });
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
