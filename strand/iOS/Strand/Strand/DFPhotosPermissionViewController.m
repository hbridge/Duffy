//
//  DFPhotosPermissionViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotosPermissionViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIAlertView+DFHelpers.h"
#import "DFAnalytics.h"
#import "AppDelegate.h"
#import "SAMGradientView.h"
#import "DFStrandConstants.h"
#import "DFCameraRollSyncManager.h"
#import "DFUploadController.h"
#import "DFPhotoStore.h"

@interface DFPhotosPermissionViewController ()

@end

@implementation DFPhotosPermissionViewController

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
  
  SAMGradientView *gradientView = (SAMGradientView *)self.view;
  gradientView.gradientColors = @[[UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.9 alpha:1.0]];
  [self.navigationController setNavigationBarHidden:YES];
  [self setNeedsStatusBarAppearanceUpdate];
  
  self.imageView.alpha = 0.9;
  self.imageView.layer.cornerRadius = 6.0;
  self.imageView.layer.masksToBounds = YES;
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

- (IBAction)grantPhotosAccessPressed:(id)sender {
  ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
  if (status == ALAuthorizationStatusAuthorized) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"alreadyGranted"];
    [self showNextStep];
  } else if (status == ALAuthorizationStatusDenied) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"alreadyDenied"];
    [UIAlertView showSimpleAlertWithTitle:@"Enable Access"
                                  message:@"Please give this app permission to access your photo library in Settings."];
  } else if (status == ALAuthorizationStatusRestricted) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"restricted"];
    [UIAlertView showSimpleAlertWithTitle:@"Restricted"
                                  message:@"Access to the photo library is restricted on this phone."];
  } else if (status == ALAuthorizationStatusNotDetermined) {
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      [DFAnalytics logSetupPhotosCompletedWithResult:@"askedGranted"];
      [self showNextStep];
      *stop = YES;
    } failureBlock:^(NSError *error) {
      if (error) {
        [UIAlertView showSimpleAlertWithTitle:@"Error"
                                      message:[NSString stringWithFormat:@"%@",
                                               error.localizedDescription]];
        DDLogWarn(@"Couldn't access camera roll, code: %ld", (long)error.code);
        [DFAnalytics logSetupPhotosCompletedWithResult:@"error"];
      }else{
        [DFAnalytics logSetupPhotosCompletedWithResult:@"askedDenied"];
      }
    }];
  }
}

- (void)showNextStep
{
  dispatch_async(dispatch_get_main_queue(), ^{
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate firstTimeSetupComplete];
  });
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end
