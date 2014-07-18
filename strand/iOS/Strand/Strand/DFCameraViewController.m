//
//  DFCameraViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraViewController.h"
#import "DFAnalytics.h"
#import "DFStrandsManager.h"
#import "DFCameraOverlayView.h"
#import "DFDataHasher.h"
#import "DFLocationStore.h"
#import "DFMultiPhotoViewController.h"
#import "DFPeanutLocationAdapter.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFPhotoViewController.h"
#import "DFStrandConstants.h"
#import "DFUploadController.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "RootViewController.h"
#import "UIImage+Resize.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhotoAsset.h"
#import "DFCameraRollPhotoAsset.h"
#import "DFStrandPhotoAsset.h"
#import "DFNearbyFriendsManager.h"
#import "UIAlertView+DFHelpers.h"
#import "RestKit/RestKit.h"
#import "DFDefaultsStore.h"
#import "DFSettings.h"
#import "DFLocationRoadblockViewController.h"
#import "DFPermissionsHelpers.h"

static NSString *const DFStrandCameraHelpWasShown = @"DFStrandCameraHelpWasShown";
static NSString *const DFStrandCameraJoinableHelpWasShown = @"DFStrandCameraJoinableHelpWasShown";

const unsigned int MaxRetryCount = 3;
const CLLocationAccuracy MinLocationAccuracy = 65.0;
const NSTimeInterval MaxLocationAge = 15 * 60;
const unsigned int RetryDelaySecs = 5;
const NSTimeInterval WifiPromptInterval = 10 * 60;
const unsigned int SavePromptMinPhotos = 3;

@interface DFCameraViewController ()

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) DFPeanutLocationAdapter *locationAdapter;
@property (nonatomic, retain) NSTimer *updateUITimer;
@property (nonatomic, retain) NSDate *lastWifiPromptDate;
@property (readonly, nonatomic, retain) DFLocationRoadblockViewController *locationRoadblockViewController;

@end

@implementation DFCameraViewController

@synthesize customCameraOverlayView = _customCameraOverlayView;
@synthesize locationAdapter = _locationAdapter;
@synthesize locationRoadblockViewController = _locationRoadblockViewController;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [self configureLocationManager];
    [self observeNotifications];
    self.lastWifiPromptDate = [NSDate dateWithTimeIntervalSince1970:0];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateUnseenCount:)
                                               name:DFStrandUnseenPhotosUpdatedNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(joinableStrandsUpdated:)
                                               name:DFStrandJoinableStrandsNearbyNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateNearbyFriendsBar:)
                                               name:DFNearbyFriendsMessageUpdatedNotificationName
                                             object:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    self.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.view.backgroundColor = [UIColor blackColor];
    self.showsCameraControls = NO;
    self.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
    self.customCameraOverlayView.flashButton.tag = (NSInteger)UIImagePickerControllerCameraFlashModeAuto;
    self.cameraOverlayView = self.customCameraOverlayView;
    [self.customCameraOverlayView updateUIForFlashMode:UIImagePickerControllerCameraFlashModeAuto];
  } else {
    self.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    //[self.view addSubview:self.customCameraOverlayView];
  }
  
  self.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:YES];
  [self updateUnseenCount:nil];
}

- (void)updateUnseenCount:(NSNotification *)note
{
  int unseenCount;
  if (note) {
    NSNumber *unseenNumber = note.userInfo[DFStrandUnseenPhotosUpdatedCountKey];
    unseenCount = unseenNumber.intValue;
  } else {
    unseenCount =  [[DFStrandsManager sharedStrandsManager] numUnseenPhotos];
  }
  
  NSString *unseenCountString = [NSString stringWithFormat:@"%d", unseenCount];
  dispatch_async(dispatch_get_main_queue(), ^{
    if (![self.customCameraOverlayView.galleryButton.titleLabel.text isEqualToString:unseenCountString]) {
      if (unseenCount > 0) {
        self.customCameraOverlayView.galleryButton.titleLabel.textColor = [UIColor orangeColor];
        [self.customCameraOverlayView.galleryButton setTitle:unseenCountString forState:UIControlStateNormal];
      } else {
        self.customCameraOverlayView.galleryButton.titleLabel.textColor = [UIColor orangeColor];
        [self.customCameraOverlayView.galleryButton setTitle:@"" forState:UIControlStateNormal];
      }
    }
  });
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self viewDidAppearFromBackground:NO];
}


- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self viewDidDisappearToBackground:NO];
}

- (void)configureLocationManager
{
  self.locationManager = [[CLLocationManager alloc] init];
  self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  self.locationManager.distanceFilter = 10;
  self.locationManager.delegate = self;
}

- (void)viewDidAppearFromBackground:(BOOL)fromBackground
{
  [self updateServerUI];
  if (!self.updateUITimer) {
    self.updateUITimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                          target:self
                                                        selector:@selector(updateServerUI)
                                                        userInfo:nil
                                                         repeats:YES];
  }
  [self startLocationUpdates];
  [self showHelpTextIfNeeded];
  
  
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)updateServerUI
{
  [self updateUnseenCount:nil];
  [self updateNearbyFriendsBar:nil];
}

- (void)viewDidDisappearToBackground:(BOOL)toBackground
{
  [self stopLocationUpdates];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
  [self.updateUITimer invalidate];
  self.updateUITimer = nil;
}

- (void)applicationDidBecomeActive:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidAppearFromBackground:YES];
  }
}

- (void)applicationDidEnterBackground:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidDisappearToBackground:YES];
  }
}

- (void)startLocationUpdates
{
  DDLogVerbose(@"DFCameraViewController starting location updates.");
  [self.locationManager stopUpdatingLocation];
  [self.locationManager startUpdatingLocation];
}

- (void)stopLocationUpdates
{
  DDLogVerbose(@"DFCameraViewController stopping location updates.");
  [self.locationManager stopUpdatingLocation];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Overlay setup

- (DFCameraOverlayView *)customCameraOverlayView
{
  if (!_customCameraOverlayView) {
    _customCameraOverlayView = [[[UINib nibWithNibName:@"DFCameraOverlayView" bundle:nil]
                           instantiateWithOwner:self options:nil]
                          firstObject];
    _customCameraOverlayView.frame = self.view.frame;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
      // only wire up buttons if we're not in the simulator
      [_customCameraOverlayView.takePhotoButton addTarget:self
                                                   action:@selector(takePhotoButtonPressed:)
                                         forControlEvents:UIControlEventTouchUpInside];
      [_customCameraOverlayView.galleryButton addTarget:self
                                                 action:@selector(galleryButtonPressed:)
                                       forControlEvents:UIControlEventTouchUpInside];
      [_customCameraOverlayView.flashButton addTarget:self
                                               action:@selector(flashButtonPressed:)
                                     forControlEvents:UIControlEventTouchUpInside];
      [_customCameraOverlayView.swapCameraButton addTarget:self
                                                    action:@selector(swapCameraButtonPressed:)
                                          forControlEvents:UIControlEventTouchUpInside];
    }
  }

  return _customCameraOverlayView;
}

- (UIImage *)imageForLastPhoto
{
  NSArray *allPhotos = [[[DFPhotoStore sharedStore] mostRecentPhotos:1] photosByDateAscending:NO];
  DDLogVerbose(@"imageForLastPhoto allPhotos count: %d", (int)allPhotos.count);
  DFPhoto *photo =  [allPhotos firstObject];
  if (photo) return photo.asset.thumbnail;
  
  return nil;
}

- (void)showHelpTextIfNeeded
{
  BOOL wasShown = [[NSUserDefaults standardUserDefaults] boolForKey:DFStrandCameraHelpWasShown];
  if (wasShown) return;
  
  NSTimer *timer = [NSTimer timerWithTimeInterval:2.0
                                           target:self.customCameraOverlayView
                                         selector:@selector(showHelpText)
                                         userInfo:nil
                                          repeats:NO];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)showJoinableHelpTextIfNeeded
{
  BOOL helpWasShown = [[NSUserDefaults standardUserDefaults]
                                boolForKey:DFStrandCameraHelpWasShown];
  BOOL joinableWasShown = [[NSUserDefaults standardUserDefaults]
                   boolForKey:DFStrandCameraJoinableHelpWasShown];
  if (!helpWasShown || joinableWasShown) return;
  
  NSTimer *timer = [NSTimer timerWithTimeInterval:2.0
                                           target:self.customCameraOverlayView
                                         selector:@selector(showJoinableHelpText)
                                         userInfo:nil
                                          repeats:NO];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)updateNearbyFriendsBar:(NSNotification *)note
{
  NSString *message;
  NSString *expandedMessage;
  if (note) {
    message = note.userInfo[DFNearbyFriendsNotificationMessageKey];
    expandedMessage = note.userInfo[DFNearbyFriendsNotificationExpandedMessageKey];
  } else {
    message = [[DFNearbyFriendsManager sharedManager] nearbyFriendsMessage];
    expandedMessage = [[DFNearbyFriendsManager sharedManager] expandedNearbyFriendsMessage];
    
    if ((!message || [message isEqualToString:@""])
        && ![self isGoodLocation:self.locationManager.location]) {
      // add a message to the bar that the location fix is bad
      message = @"Location inaccurate. Tap for more info.";
      expandedMessage = @"Could not get an accurate location for your phone. ";
      
      if ([[[RKObjectManager sharedManager] HTTPClient] networkReachabilityStatus] == AFNetworkReachabilityStatusReachableViaWiFi) {
        expandedMessage = [expandedMessage
                           stringByAppendingString:@"Nearby friends might be missing."];
      } else {
        expandedMessage = [expandedMessage
                           stringByAppendingString:@"Please turn on WiFi if it's off to improve location accuracy."];
      }
    }
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (message && ![message isEqualToString:@""]) {
      self.customCameraOverlayView.nearbyFriendsLabel.text = message;
    } else {
      self.customCameraOverlayView.nearbyFriendsLabel.text = @"";
    }
    
    [self.customCameraOverlayView setNearbyFriendsHelpText:expandedMessage];
  });
}


#pragma mark - User actions

- (void)takePhotoButtonPressed:(UIButton *)sender
{
  DDLogInfo(@"Take photo button pressed.");
  [self takePicture];
  [self flashCameraView];
  [self handleNUXTasksForPhotoTaken];
  [DFDefaultsStore incrementCountForAction:UserActionTakePhoto];
}

- (void)handleNUXTasksForPhotoTaken
{
  BOOL cameraHelpWasShown = [[NSUserDefaults standardUserDefaults] boolForKey:DFStrandCameraHelpWasShown];
  BOOL joinableHelpWasShown = [[NSUserDefaults standardUserDefaults] boolForKey:DFStrandCameraJoinableHelpWasShown];

  if (!cameraHelpWasShown) {
    [self.customCameraOverlayView hideHelpText];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:DFStrandCameraHelpWasShown];
  } else {
    if (!joinableHelpWasShown) {
      [self.customCameraOverlayView hideJoinableHelpText];
      [[NSUserDefaults standardUserDefaults] setBool:YES forKey:DFStrandCameraJoinableHelpWasShown];
    }
  }
  
  unsigned int photoTakenCount = [DFDefaultsStore actionCountForAction:UserActionTakePhoto];
  BOOL saveAsked = [DFDefaultsStore isSetupStepPassed:DFSetupStepAskToAutoSaveToCameraRoll];
  if (photoTakenCount > SavePromptMinPhotos
      && !saveAsked
      && ![[DFSettings sharedSettings] autosaveToCameraRoll]) {
    [self showAutoSavePrompt];
  }
}

- (void)showAutoSavePrompt
{
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Auto-Save Photos?"
                                                  message:@"Would you like photos you take in Strand to automatically be saved to your Camera Roll?"
                                                 delegate:self
                                        cancelButtonTitle:@"Not Now"
                                        otherButtonTitles:@"Yes", nil];
  [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex > 0) {
    [[DFSettings sharedSettings] setAutosaveToCameraRoll:YES];
  }
  
  [DFDefaultsStore setSetupStepPassed:DFSetupStepAskToAutoSaveToCameraRoll Passed:YES];
}

- (void)galleryButtonPressed:(UIButton *)sender
{
  [(RootViewController *)self.view.window.rootViewController showGallery];
}

- (void)flashButtonPressed:(UIButton *)flashButton
{
  UIImagePickerControllerCameraFlashMode newMode;
  if (flashButton.tag == (NSInteger)UIImagePickerControllerCameraFlashModeAuto) {
    newMode = UIImagePickerControllerCameraFlashModeOn;
  } else if (flashButton.tag == (NSInteger)UIImagePickerControllerCameraFlashModeOn) {
    newMode = UIImagePickerControllerCameraFlashModeOff;
  } else if (flashButton.tag == (NSInteger)UIImagePickerControllerCameraFlashModeOff) {
    newMode = UIImagePickerControllerCameraFlashModeAuto;
  }
  
  flashButton.tag = newMode;
  self.cameraFlashMode = newMode;
  [self.customCameraOverlayView updateUIForFlashMode:newMode];
}

- (void)swapCameraButtonPressed:(UIButton *)sender
{
  if (self.cameraDevice == UIImagePickerControllerCameraDeviceFront) {
    self.cameraDevice = UIImagePickerControllerCameraDeviceRear;
  } else if (self.cameraDevice == UIImagePickerControllerCameraDeviceRear) {
    self.cameraDevice = UIImagePickerControllerCameraDeviceFront;
  }
}

- (void)flashCameraView
{
  [UIView animateWithDuration:0.3 animations:^{
    self.cameraOverlayView.backgroundColor = [UIColor blackColor];
  } completion:^(BOOL finished) {
    if (finished) [UIView animateWithDuration:0.3 animations:^{
      self.cameraOverlayView.backgroundColor = [UIColor clearColor];
    }];
  }];
}

#pragma mark - Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
  DDLogInfo(@"%@ image picked", [self.class description]);
  
  NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
  UIImage *imageToSave;
  
  // Handle a still image capture
  if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
      == kCFCompareEqualTo) {
    imageToSave = (UIImage *) [info objectForKey:
                               UIImagePickerControllerOriginalImage];
    NSDictionary *metadata = (NSDictionary *)info[UIImagePickerControllerMediaMetadata];
    [self saveImage:imageToSave withMetadata:metadata retryAttempt:0 completionBlock:^{
      [[DFUploadController sharedUploadController] uploadPhotos];
    }];
    [self animateImageCaptured:imageToSave];
    
    if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
      [DFAnalytics logPhotoTakenWithCamera:self.cameraDevice flashMode:self.cameraFlashMode];
    }
  }
}

- (void)animateImageCaptured:(UIImage *)image{
  dispatch_async(dispatch_get_main_queue(), ^{
    CGRect imageViewFrame = CGRectMake(self.view.frame.origin.x,
                                       self.view.frame.origin.y,
                                       320,
                                       348);
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
    imageView.image = image;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    [self.customCameraOverlayView addSubview:imageView];
    
    [UIView animateWithDuration:0.5 animations:^{
      // Change the position explicitly.
      imageView.frame = self.customCameraOverlayView.galleryButton.frame;
      imageView.alpha = 0.1;
    } completion:^(BOOL finished) {
      [imageView removeFromSuperview];
    }];
  });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
  [self galleryButtonPressed:nil];
}

- (void)saveImage:(UIImage *)image
     withMetadata:(NSDictionary *)metadata
     retryAttempt:(unsigned int)retryAttempt
  completionBlock:(void (^)(void))completionBlock
{
  CLLocation *location = self.locationManager.location;
  
  if (![self isGoodLocation:location] && retryAttempt <= MaxRetryCount) {
    //wait for a better location fix
    DDLogWarn(@"DFCameraViewController got bad location fix.  Retrying in %ds", RetryDelaySecs);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RetryDelaySecs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self saveImage:image withMetadata:metadata retryAttempt:retryAttempt + 1 completionBlock:completionBlock];
    });
    
    return;
  }
  
  NSMutableDictionary *mutableMetadata = [[NSMutableDictionary alloc] initWithDictionary:metadata];
  [self addLocation:location toMetadata:mutableMetadata];
  [self addCachedLocationToMetadata:mutableMetadata];
  
  // Save the assset locally
  NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
  NSData *data = UIImageJPEGRepresentation(image, 0.8);
  DFStrandPhotoAsset *asset = [DFStrandPhotoAsset createAssetForImageData:data
                                      photoID:0
                                     metadata:mutableMetadata
                                     location:location
                                 creationDate:[NSDate date]
                                    inContext:context];
  
  DFPhoto *photo = [DFPhoto createWithAsset:asset
                    userID:[[DFUser currentUser] userID]
                  timeZone:[NSTimeZone defaultTimeZone]
                 inContext:context];
  
  DDLogVerbose(@"New photo date:%@", [[NSDateFormatter DjangoDateFormatter]
                                      stringFromDate:photo.creationDate]);
  
  // Save the database changes
  NSError *error;
  [context save:&error];
  if (error) {
    [NSException raise:@"Couldn't save database after creating DFStrandPhotoAsset"
                format:@"Error: %@", error.description];
  }
  
  if ([[DFSettings sharedSettings] autosaveToCameraRoll]) {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:image.CGImage
                                 metadata:metadata
    completionBlock:^(NSURL *assetURL, NSError *error) {
      if (error) {
        DDLogError(@"%@ couldn't save photo to Camera Roll:%@", [DFCameraViewController class],
                   error.description);
      }
    }];
  }
  
  if (completionBlock) completionBlock();
}

- (BOOL)isGoodLocation:(CLLocation *)location
{
  BOOL result = NO;
  if (location.horizontalAccuracy <= MinLocationAccuracy &&
      [[NSDate date] timeIntervalSinceDate:location.timestamp] <= MaxLocationAge) {
    result = YES;
  }
  
  return result;
}

- (void)addLocation:(CLLocation *)location toMetadata:(NSMutableDictionary *)metadata
{
  CLLocation *cachedLocation = [DFLocationStore LoadLastLocation];
  
  DDLogInfo(@"DFCameraViewController addLocationToMetadata location age %.01fs cached location age %.01fs",
            [[NSDate date] timeIntervalSinceDate:location.timestamp],
            [[NSDate date] timeIntervalSinceDate:cachedLocation.timestamp]);
  
  if (location == nil && cachedLocation == nil) return;

  CLLocation *locationToUse;
  if (!cachedLocation || [location.timestamp timeIntervalSinceDate:cachedLocation.timestamp] >= 0.0) {
    // if our location manager has updated since the cached location has, use the newer val
    DDLogInfo(@"DFCameraViewController using uncached location data");
    locationToUse = location;
  } else {
    DDLogInfo(@"DFCameraViewController using cached location data");
    locationToUse = cachedLocation;
  }
  
  CLLocationCoordinate2D coords = locationToUse.coordinate;
  CLLocationDistance altitude = locationToUse.altitude;

  NSDictionary *latlongDict = @{@"Latitude": @(fabs(coords.latitude)),
                                @"LatitudeRef" : coords.latitude >= 0.0 ? @"N" : @"S",
                                @"Longitude" : @(fabs(coords.longitude)),
                                @"LongitudeRef" : coords.longitude >= 0.0 ? @"E" : @"W",
                                @"Altitude" : @(altitude),
                                };
  
  metadata[@"{GPS}"] = latlongDict;
}

- (void)addCachedLocationToMetadata:(NSMutableDictionary *)metadata
{
  CLLocation *lastCachedLocation = [DFLocationStore LoadLastLocation];
  if (!lastCachedLocation) return;
  
  CLLocationCoordinate2D cachedCoords = lastCachedLocation.coordinate;
  
  NSMutableDictionary *exifDict = [[NSMutableDictionary alloc]
                                   initWithDictionary:metadata[@"{Exif}"]];
  
  NSNumber *cachedLat = @(fabs(cachedCoords.latitude));
  NSNumber *cachedLon = @(fabs(cachedCoords.longitude));
  NSString *cachedDateRec = [[NSDateFormatter DjangoDateFormatter]
                          stringFromDate:lastCachedLocation.timestamp];
  NSString *GPSTagDateRec = [[NSDateFormatter DjangoDateFormatter] stringFromDate:self.locationManager.location.timestamp];
  
  NSDictionary *cachedLatlongDict = @{@"CachedLatitude": cachedLat,
                                      @"CachedLatitudeRef" : cachedCoords.latitude >= 0.0 ? @"N" : @"S",
                                      @"CachedLongitude" : cachedLon,
                                      @"CachedLongitudeRef" : cachedCoords.longitude >= 0.0 ? @"E" : @"W",
                                      @"CachedDateTimeRecorded" : cachedDateRec ? cachedDateRec : @"",
                                      @"GPSTagDateTimeRecored" : GPSTagDateRec ? GPSTagDateRec : @""
                                      };
  exifDict[@"UserComment"] = cachedLatlongDict.description;
  metadata[@"{Exif}"] = exifDict;
}


- (void)joinableStrandsUpdated:(NSNotification *)note
{
  NSNumber *count = note.userInfo[DFStrandJoinableStrandsCountKey];
  UIImage *newImage;
  if (count.intValue > 0) {
    newImage = [UIImage imageNamed:@"Assets/Icons/ShutterButtonHighlighted.png"];
    [self showJoinableHelpTextIfNeeded];
  } else {
    newImage = [UIImage imageNamed:@"Assets/Icons/ShutterButton.png"];
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.customCameraOverlayView.takePhotoButton
     setImage:newImage
     forState:UIControlStateNormal];
  });
}


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  CLLocation *location = locations.lastObject;
  if ([self isGoodLocation:location]) {
    [self updateServerUI];
  }
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [DFPermissionsHelpers recordAndLogPermission:DFPermissionLocation
                                       changedTo:DFPermissionStateGranted];
  });
  
  DDLogInfo(@"DFCameraViewController updated location: <%f, %f> +/- %.02fm @ %@",
            location.coordinate.latitude,
            location.coordinate.longitude,
            location.horizontalAccuracy,
            location.timestamp
            );
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  DDLogInfo(@"%@ location update failed: %@", [self.class description], error.description);
  if (error.code == kCLErrorDenied && !self.presentedViewController) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [DFPermissionsHelpers recordAndLogPermission:DFPermissionLocation
                                         changedTo:DFPermissionStateGranted];
    });
    [self presentViewController:self.locationRoadblockViewController animated:YES completion:nil];
  }
}

- (DFPeanutLocationAdapter *)locationAdapter
{
  if (!_locationAdapter) {
    _locationAdapter = [[DFPeanutLocationAdapter alloc] init];
  }
  
  return _locationAdapter;
}

- (UIViewController *)locationRoadblockViewController
{
  if (!_locationRoadblockViewController) {
    _locationRoadblockViewController = [[DFLocationRoadblockViewController alloc] init];
  }
  
  return _locationRoadblockViewController;
}

@end
