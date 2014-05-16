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
#import "DFAutocompleteController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "DFLocationPinger.h"
#import "DFIntroPageViewController.h"
#import "DFUploadController.h"
#import "DFNotificationSharedConstants.h"

unsigned long MinNumThumbnailsToTransition = 100;

@interface DFIntroContentViewController ()

@property (nonatomic, retain) DFAutocompleteController *autoCompleteController;
@property (nonatomic) dispatch_semaphore_t nextStepSemaphore;

@end

@implementation DFIntroContentViewController

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
  
  if (self.pageIndex == 0) {
    [self configureWelcomeScreen];
  } else if (self.pageIndex == 1) {
    [self configureUploadScreen];
  } else if (self.pageIndex == 2) {
    [self configureDoneScreen];
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
  
  // run actions for welcome
  [self getUserID];
}

- (void)configureUploadScreen
{
  self.titleLabel.text = @"Uploading";
  self.contentLabel.attributedText = [self attributedStringForPage:1];
  [self.activityIndicator startAnimating];
  self.actionButton.hidden = YES;
  
  // run actions for upload
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(uploadStatusChanged:)
                                               name:DFUploadStatusNotificationName
                                             object:nil];
  [[DFUploadController sharedUploadController] uploadPhotos];
}

- (void)configureDoneScreen
{
  self.titleLabel.text = @"Ready to Search";
  
  DFIntroContentViewController __weak *weakSelf = self;
  self.autoCompleteController = [[DFAutocompleteController alloc] init];
  [self.autoCompleteController fetchSuggestions:^(NSArray *categoryPeanutSuggestions,
                                             NSArray *locationPeanutSuggestions,
                                             NSArray *timePeanutSuggestions) {
//    [weakSelf showDoneTextWithTimeSuggestions:timePeanutSuggestions
//                      locationSuggestions:locationPeanutSuggestions
//                         thingSuggestions:categoryPeanutSuggestions];
    
    DFPeanutSuggestion *timePeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    timePeanutSuggestion.name = @"last week";
    timePeanutSuggestion.count = 5;
    
    DFPeanutSuggestion *locationPeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    locationPeanutSuggestion.name = @"New York";
    locationPeanutSuggestion.count = 100;
    
    DFPeanutSuggestion *thingPeanutSuggestion = [[DFPeanutSuggestion alloc] init];
    thingPeanutSuggestion.name = @"Nutriment";
    thingPeanutSuggestion.count = 15;
    
    [weakSelf showDoneTextWithTimeSuggestions:@[timePeanutSuggestion]
                          locationSuggestions:@[locationPeanutSuggestion]
                             thingSuggestions:@[thingPeanutSuggestion]];
    
  }];
  
  
  [self.actionButton setTitle:@"Get Started" forState:UIControlStateNormal];
  self.activityIndicator.hidden = YES;
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
  
  DFPeanutSuggestion *timeSuggestion = [timeSuggestions firstObject];
  if (timeSuggestion) {
    [formatString replaceOccurrencesOfString:@"%TimeNumber"
                                            withString:[NSString stringWithFormat:@"%d", timeSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%TimeString"
                                            withString:[timeSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
  DFPeanutSuggestion *locationSuggestion = [locationSuggestions firstObject];
  if (locationSuggestion) {
    [formatString replaceOccurrencesOfString:@"%LocationNumber"
                                            withString:[NSString stringWithFormat:@"%d", locationSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%LocationString"
                                            withString:[locationSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
  DFPeanutSuggestion *thingSuggestion = [thingSuggestions firstObject];
  if (locationSuggestion) {
    [formatString replaceOccurrencesOfString:@"%ThingNumber"
                                            withString:[NSString stringWithFormat:@"%d", thingSuggestion.count]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
    [formatString replaceOccurrencesOfString:@"%ThingString"
                                            withString:[thingSuggestion.name capitalizedString]
                                               options:0
                                                 range:NSMakeRange(0, attributedFormatString.length)];
  }
  
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
    DDLogInfo(@"Asking for user permissions.");
  
  [self checkForAndRequestPhotoAccess];
  dispatch_semaphore_wait(self.nextStepSemaphore, DISPATCH_TIME_FOREVER);
  [self checkForAndRequestLocationAccess];
  dispatch_semaphore_wait(self.nextStepSemaphore, DISPATCH_TIME_FOREVER);
  
  [self.pageViewController showNextStep:self];
}

- (void)dimsissIntro:(id)sender
{
  DDLogInfo(@"User dismissed intro");
  [self.pageViewController showNextStep:self];
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
                                               [NSException raise:@"No user" format:@"Failed to get or create user for device ID."];
                                               dispatch_semaphore_signal(self.nextStepSemaphore);
                                             }];
                     }
                   } failureBlock:^(NSError *error) {
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
  DDLogInfo(@"Intro thumbnails uploaded %lu", uploadStats.numThumbnailsUploaded);
  if (uploadStats.numThumbnailsUploaded > MinNumThumbnailsToTransition || uploadStats.numThumbnailsRemaining == 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.pageViewController showNextStep:self];
    });
  }
}


@end
