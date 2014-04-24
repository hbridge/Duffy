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
#import <AssetsLibrary/AssetsLibrary.h>

@interface DFFirstTimeSetupViewController ()

@property (nonatomic, retain) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, weak) DFAppDelegate *appDelegate;

@end

@implementation DFFirstTimeSetupViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.appDelegate = (DFAppDelegate *)[[UIApplication sharedApplication] delegate];
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
    DDLogInfo(@"Running first time setup.");
    [DFAnalytics logViewController:self appearedWithParameters:nil];
    
    [self.activityIndicatorView startAnimating];
    
    ALAuthorizationStatus photoAuthStatus = [ALAssetsLibrary authorizationStatus];
    if (photoAuthStatus == ALAuthorizationStatusDenied || photoAuthStatus == ALAuthorizationStatusRestricted) {
        DDLogInfo(@"Photo access is denied, showing alert and quitting.");
        [self showGrantPhotoAccessAlertAndQuit];
    } else if (photoAuthStatus == ALAuthorizationStatusNotDetermined) {
         DDLogInfo(@"Photo access not determined, asking.");
        [self askForPhotosPermission];
    } else if (photoAuthStatus == ALAuthorizationStatusAuthorized) {
        [self handleUserGrantedPhotoAccess];
        DDLogInfo(@"Seem to already have photo access.");
    } else {
        DDLogError(@"Unknown photo access value: %d", (int)photoAuthStatus);
    }
}
- (void)askForPhotosPermission
{
    // request access to user's photos
    DDLogInfo(@"Asking for photos permission.");
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (group == nil) [self handleUserGrantedPhotoAccess];
    } failureBlock:^(NSError *error) {
        if (error.code == ALAssetsLibraryAccessUserDeniedError) {
            DDLogError(@"User denied access, code: %li",(long)error.code);
        }else{
            DDLogError(@"Other error code: %li",(long)error.code);
        }
        [self showGrantPhotoAccessAlertAndQuit];
    }];

}

- (void)handleUserGrantedPhotoAccess
{
    DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
    [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID]
                     withSuccessBlock:^(DFUser *user) {
                         if (user) {
                             [[DFUser currentUser] setUserID:user.userID];
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self.appDelegate showLoggedInUserTabs];
                             });
                         } else {
                             // the request succeeded, but the user doesn't exist, we have to create it
                             [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                                                     deviceName:[[DFUser currentUser] deviceName]
                                               withSuccessBlock:^(DFUser *user) {
                                                   [[DFUser currentUser] setUserID:user.userID];
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       [self.appDelegate showLoggedInUserTabs];
                                                   });
                                               }
                                                   failureBlock:^(NSError *error) {
                                                       [NSException raise:@"No user" format:@"Failed to get or create user for device ID."];
                                                   }];
                         }
                     } failureBlock:^(NSError *error) {
                         [self.appDelegate showLoggedInUserTabs];
                     }];
}

- (void)showGrantPhotoAccessAlertAndQuit
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Access Required"
                                                    message:@"Please give this app permission to access your photo library in your settings app!" delegate:nil
                                          cancelButtonTitle:@"Quit"
                                          otherButtonTitles:nil, nil];
    alert.delegate = self;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    exit(0);
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
