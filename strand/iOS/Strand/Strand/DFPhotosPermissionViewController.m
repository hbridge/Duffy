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
#import "SAMGradientView.h"
#import "DFStrandConstants.h"
#import "DFCameraRollSyncManager.h"
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFSettings.h"

@interface DFPhotosPermissionViewController ()

@property (nonatomic) BOOL calledCompleted;

@end

@implementation DFPhotosPermissionViewController

- (instancetype)init
{
  self = [super initWithTitle:@"Photos Access"
                        image:[UIImage imageNamed:@"Assets/Nux/PhotosAccessGraphic"]
              explanationText:@"Get suggestions for best photos to share from your photo library"
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
  ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
  if (status == ALAuthorizationStatusAuthorized) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"alreadyGranted"];
    [self completedWithGranted:YES];
  } else if (status == ALAuthorizationStatusDenied) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"alreadyDenied"];
    [DFSettings showPermissionDeniedAlert];
  } else if (status == ALAuthorizationStatusRestricted) {
    [DFAnalytics logSetupPhotosCompletedWithResult:@"restricted"];
    [UIAlertView showSimpleAlertWithTitle:@"Restricted"
                                  message:@"Access to the photo library is restricted on this phone."];
  } else if (status == ALAuthorizationStatusNotDetermined) {
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      [DFAnalytics logSetupPhotosCompletedWithResult:@"askedGranted"];
      [self completedWithGranted:YES];
      *stop = YES;
    } failureBlock:^(NSError *error) {
      if (error) {
        [UIAlertView showSimpleAlertWithTitle:@"Error"
                                      message:[NSString stringWithFormat:@"%@",
                                               error.localizedDescription]];
        DDLogWarn(@"Couldn't access camera roll, code: %ld", (long)error.code);
        [DFAnalytics logSetupPhotosCompletedWithResult:@"error"];
      } else {
        [DFAnalytics logSetupPhotosCompletedWithResult:@"askedDenied"];
        [DFSettings showPermissionDeniedAlert];
      }
    }];
  }
}

- (void)completedWithGranted:(BOOL)granted
{
  if (!self.calledCompleted && granted) {
    self.calledCompleted = YES;
    [[DFCameraRollSyncManager sharedManager] sync];
    [[DFUploadController sharedUploadController] uploadPhotos];
    [self completedWithUserInfo:nil];
  }
}


@end
