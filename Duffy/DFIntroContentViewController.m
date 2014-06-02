//
//  DFIntroPageViewController.m
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFIntroContentViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPeanutSuggestion.h"
#import "DFSuggestionAdapter.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "DFLocationPinger.h"
#import "DFIntroPageViewController.h"
#import "DFUploadController.h"
#import "DFNotificationSharedConstants.h"
#import "DFCameraRollSyncController.h"
#import "DFPhotoStore.h"

unsigned long MinNumThumbnailsToTransition = 100;
unsigned int MaxAutocompleteFetchRetryCount = 5;

DFIntroContentType DFIntroContentWelcome = @"DFIntroContentWelcome";
DFIntroContentType DFIntroContentUploading = @"DFIntroContentUploading";
DFIntroContentType DFIntroContentDone = @"DFIntroContentDone";
DFIntroContentType DFIntroContentErrorUploading = @"DFIntroContentErrorUploading";
DFIntroContentType DFIntroContentErrorNoUser = @"DFIntroContentErrorNoUser";

@interface DFIntroContentViewController ()

@property (nonatomic, retain) DFSuggestionAdapter *autoCompleteController;
@property (nonatomic) dispatch_semaphore_t nextStepSemaphore;

@end

@implementation DFIntroContentViewController

@synthesize introContent;

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
  
  self.nextStepSemaphore = dispatch_semaphore_create(0);
  
  if (self.introContent == DFIntroContentWelcome) {
    [self configureWelcomeScreen];
    [self getUserID];
  } else if (self.introContent == DFIntroContentUploading) {
    [self configureUploadScreen];
    if ([[[[DFPhotoStore sharedStore] cameraRoll] photoURLSet] count] > 0
        || [[DFCameraRollSyncController  sharedSyncController] isSyncInProgress]) {
      [self runUploadProcess];
    } else {
      self.introContent = DFIntroContentDone;
      [self configureDoneScreen];
    }
  } else if (self.introContent == DFIntroContentDone) {
    [self configureDoneScreen];
  } else if (self.introContent == DFIntroContentErrorUploading) {
    [self configureErrorUploading];
  } else if (self.introContent == DFIntroContentErrorNoUser) {
    [self configureUserError];
  }
}

- (void)configureWelcomeScreen
{
  self.titleLabel.text = @"Welcome";
  self.contentLabel.attributedText = [self attributedStringForPage:0];
  
  self.activityIndicator.hidden = YES;
  [self.actionButton setTitle:@"Grant Permission" forState:UIControlStateNormal];
  [self.actionButton addTarget:self
                        action:@selector(askForPermissions:)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureUploadScreen
{
  self.titleLabel.text = @"Uploading";
  self.contentLabel.attributedText = [self attributedStringForPage:1];
  [self.activityIndicator startAnimating];
  self.actionButton.hidden = YES;
}

- (void)runUploadProcess
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(uploadStatusChanged:)
                                               name:DFUploadStatusNotificationName
                                             object:nil];
  [[DFUploadController sharedUploadController] uploadPhotos];
}

- (void)configureUserError
{
  self.titleLabel.text = @"Error";
  self.contentLabel.text = @"Looks like we couldn't connect to our server. Please ensure that you can connect to the internet and try again later.";
  self.activityIndicator.hidden = YES;
  [self.actionButton  setTitle:@"Try Again" forState:UIControlStateNormal];
  [self. actionButton addTarget:self
                         action:@selector(tryWelcomeAgain:)
               forControlEvents:UIControlEventTouchUpInside];
}

- (void)tryWelcomeAgain:(UIButton *)sender
{
  [self.pageViewController showNextContentViewController:DFIntroContentWelcome];
}


- (void)configureErrorUploading
{
  self.titleLabel.text = @"Error";
  self.contentLabel.text = @"Looks like we couldn't upload your photos. Please ensure that you can connect to the internet and try again later.";
  self.activityIndicator.hidden = YES;
  [self.actionButton setTitle:@"Try Again" forState:UIControlStateNormal];
  [self.actionButton addTarget:self
                        action:@selector(tryUploadAgain:)
              forControlEvents:UIControlEventTouchUpInside];
}



- (void)tryUploadAgain:(UIButton *)sender
{
  [self.pageViewController showNextContentViewController:DFIntroContentUploading];
}

- (void)configureDoneScreen
{
  self.titleLabel.text = @"Ready to Search";
  
  DFIntroContentViewController __weak *weakSelf = self;
  self.autoCompleteController = [[DFSuggestionAdapter alloc] init];
  [self.autoCompleteController fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                                  NSArray *locationPeanutSuggestions,
                                                  NSArray *timePeanutSuggestions) {
    
    if (categoryPeanutSuggestions.count == 0 &&
        locationPeanutSuggestions.count == 0 &&
        timePeanutSuggestions.count == 0) {
      weakSelf.contentLabel.text = @"Start searching!  We'll keep uploading your photos in the background.";
    } else {
      [weakSelf showDoneTextWithTimeSuggestions:timePeanutSuggestions
                        locationSuggestions:locationPeanutSuggestions
                           thingSuggestions:categoryPeanutSuggestions];
    }
    
  }];
  
  self.activityIndicator.hidden = YES;
  self.actionButton.hidden = NO;
  [self.actionButton setTitle:@"Get Started" forState:UIControlStateNormal];
  [self.actionButton addTarget:self
                        action:@selector(dimsissIntro:)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)showDoneTextWithTimeSuggestions:(NSArray *)timeSuggestions
                    locationSuggestions:(NSArray *)locationSuggestions
                       thingSuggestions:(NSArray *)thingSuggestions
{
  NSMutableAttributedString *attributedFormatString = [[self attributedStringForPage:2] mutableCopy];
  NSMutableString *formatString = [attributedFormatString mutableString];
  
  NSMutableString *categoriesString = [[NSMutableString alloc] init];
  DFPeanutSuggestion *timeSuggestion = [timeSuggestions firstObject];
  if (timeSuggestion) {
    [categoriesString appendString:[NSString stringWithFormat:@"%d photos from %@\n",
                                    timeSuggestion.count,
                                    timeSuggestion.name.capitalizedString]];
  }
  
  DFPeanutSuggestion *locationSuggestion = [locationSuggestions firstObject];
  if (locationSuggestion) {
    [categoriesString appendString:[NSString stringWithFormat:@"%d photos in %@\n",
                                    locationSuggestion.count, locationSuggestion.name]];
  }
  
  DFPeanutSuggestion *thingSuggestion = [thingSuggestions firstObject];
  if (thingSuggestion) {
    [categoriesString appendString:[NSString stringWithFormat:@"%d photos of %@\n",
                                    thingSuggestion.count, thingSuggestion.name]];
  }
  [formatString replaceOccurrencesOfString:@"%CategoriesString"
                                withString:categoriesString
                                   options:0
                                     range:NSMakeRange(0, attributedFormatString.length)];

  self.contentLabel.attributedText = attributedFormatString;
}

- (NSAttributedString *)attributedStringForPage:(unsigned int)pageNum
{
  NSError *error;
  NSString *fileName = [NSString stringWithFormat:@"%@%d", @"IntroPage", pageNum+1];
  NSURL *fileURL = [[NSBundle mainBundle] URLForResource:fileName withExtension:@"rtf"];
  NSAttributedString *result = [[NSAttributedString alloc] initWithFileURL:fileURL
                                                                         options:nil
                                                              documentAttributes:nil
                                                                           error:&error];
  
  
  
  return result;
}

#pragma mark - User/Network Action Responses

- (void)askForPermissions:(id)sender
{
  // dispatch these off main thread so we don't block it
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    DDLogInfo(@"Asking for user permissions.");
    // first semaphore wait is to wait for the get userID to complete
    dispatch_semaphore_wait(self.nextStepSemaphore, DISPATCH_TIME_FOREVER);
    if ([[DFUser currentUser] userID] == 0) {
      DDLogError(@"User create failed, not asking for permissions.");
    }
    [self checkForAndRequestPhotoAccess];
    dispatch_semaphore_wait(self.nextStepSemaphore, DISPATCH_TIME_FOREVER);
    [[DFCameraRollSyncController sharedSyncController] asyncSyncToCameraRoll];
    
    [self checkForAndRequestLocationAccess];
    dispatch_semaphore_wait(self.nextStepSemaphore, DISPATCH_TIME_FOREVER);
    
    [self.pageViewController showNextContentViewController:DFIntroContentUploading];
  });
}

- (void)dimsissIntro:(id)sender
{
  DDLogInfo(@"User dismissed intro");
  [self.pageViewController dismissIntro];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)checkForAndRequestPhotoAccess
{
  ALAuthorizationStatus photoAuthStatus = [ALAssetsLibrary authorizationStatus];
  if (photoAuthStatus == ALAuthorizationStatusDenied || photoAuthStatus == ALAuthorizationStatusRestricted) {
    DDLogInfo(@"Photo access is denied, showing alert and quitting.");
    [self showDeniedAccessAlertAndQuit];
  } else if (photoAuthStatus == ALAuthorizationStatusNotDetermined) {
    DDLogInfo(@"Photo access not determined, asking.");
    [self askForPhotosPermission];
    //while ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusNotDetermined) {
    //  sleep(0.5);
    //}
  } else if (photoAuthStatus == ALAuthorizationStatusAuthorized) {
    DDLogInfo(@"Already have photo access.");
    dispatch_semaphore_signal(self.nextStepSemaphore);
  } else {
    DDLogError(@"Unknown photo access value: %d", (int)photoAuthStatus);
    dispatch_semaphore_signal(self.nextStepSemaphore);
  }
}


- (void)askForPhotosPermission
{
  // request access to user's photos
  DDLogInfo(@"Asking for photos permission.");
  ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
  
  [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
    if (group == nil) dispatch_semaphore_signal(self.nextStepSemaphore);
  } failureBlock:^(NSError *error) {
    if (error.code == ALAssetsLibraryAccessUserDeniedError) {
      DDLogError(@"User denied access, code: %li",(long)error.code);
    }else{
      DDLogError(@"Other error code: %li",(long)error.code);
    }
    [self showDeniedAccessAlertAndQuit];
  }];
  
}


- (void)showDeniedAccessAlertAndQuit
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Access Required"
                                                    message:@"Please give this app permission to access your photo library in Settings > Privacy > Photos." delegate:nil
                                          cancelButtonTitle:@"Quit"
                                          otherButtonTitles:nil, nil];
    alert.delegate = self;
    [alert show];
    
  });
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  exit(0);
}


- (void)getUserID
{
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  DFIntroContentViewController __weak *weakSelf = self;
  [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID]
                   withSuccessBlock:^(DFUser *user) {
                     if (user) {
                       [[DFUser currentUser] setUserID:user.userID];
                       dispatch_semaphore_signal(self.nextStepSemaphore);
                     } else {
                       // the request succeeded, but the user doesn't exist, we have to create it
                       [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                                               deviceName:[[DFUser currentUser] deviceName]
                                         withSuccessBlock:^(DFUser *user) {
                                           [[DFUser currentUser] setUserID:user.userID];
                                           dispatch_semaphore_signal(self.nextStepSemaphore);
                                         }
                                             failureBlock:^(NSError *error) {
                                               DDLogWarn(@"Create user failed: %@", error.localizedDescription);
                                               [weakSelf.pageViewController
                                                showNextContentViewController:DFIntroContentErrorNoUser];
                                               dispatch_semaphore_signal(self.nextStepSemaphore);
                                             }];
                     }
                   } failureBlock:^(NSError *error) {
                     DDLogWarn(@"Get user failed: %@", error.localizedDescription);
                     [weakSelf.pageViewController
                      showNextContentViewController:DFIntroContentErrorNoUser];
                     dispatch_semaphore_signal(self.nextStepSemaphore);
                   }];
}

- (void)checkForAndRequestLocationAccess
{
  if ([[DFLocationPinger sharedInstance] haveLocationPermisison]) {
    DDLogInfo(@"Already have location access.");
  } else if ([[DFLocationPinger sharedInstance] canAskForLocationPermission])
  {
    [[DFLocationPinger sharedInstance] askForLocationPermission];
  }
  while ([[DFLocationPinger sharedInstance] canAskForLocationPermission]) {
    usleep(500);
  }
  
  dispatch_semaphore_signal(self.nextStepSemaphore);
}

- (void)uploadStatusChanged:(NSNotification *)note
{
  DFUploadSessionStats *uploadStats = note.userInfo[DFUploadStatusUpdateSessionUserInfoKey];
  DDLogInfo(@"Intro thumbnails uploaded %lu", (unsigned long)uploadStats.numThumbnailsUploaded);
  if (uploadStats.fatalError) {
    [self.pageViewController showNextContentViewController:DFIntroContentErrorUploading];
  } else if (uploadStats.numThumbnailsUploaded > MinNumThumbnailsToTransition ||
      uploadStats.numThumbnailsRemaining == 0) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [self checkForAutocompleteUntilDone:uploadStats];
    });
  }
}

static int retryCount = 0;

- (void)checkForAutocompleteUntilDone:(DFUploadSessionStats *)sessionStats
{
  DFIntroContentViewController __weak *weakSelf = self;
  self.autoCompleteController = [[DFSuggestionAdapter alloc] init];
  [self.autoCompleteController fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                                  NSArray *locationPeanutSuggestions,
                                                  NSArray *timePeanutSuggestions) {
    if (timePeanutSuggestions.count == 0 ||
        locationPeanutSuggestions.count == 0) {
      if (sessionStats.numThumbnailsUploaded > 0 && retryCount <= MaxAutocompleteFetchRetryCount) {
        sleep(2);
        retryCount++;
        [weakSelf checkForAutocompleteUntilDone:sessionStats];
      } else {
        [weakSelf.pageViewController showNextContentViewController:DFIntroContentDone];
      }
    } else {
      [weakSelf.pageViewController showNextContentViewController:DFIntroContentDone];
    }
    
  }];
  
  
  

}


@end
