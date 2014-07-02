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

static NSString *const DFStrandCameraHelpWasShown = @"DFStrandCameraHelpWasShown";
static NSString *const DFStrandCameraJoinableHelpWasShown = @"DFStrandCameraJoinableHelpWasShown";

@interface DFCameraViewController ()

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) DFPeanutLocationAdapter *locationAdapter;

@end

@implementation DFCameraViewController

@synthesize customCameraOverlayView = _customCameraOverlayView;
@synthesize locationAdapter = _locationAdapter;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [self configureLocationManager];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startLocationUpdates)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stopLocationUpdates)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateUnseenCount)
                                                 name:DFStrandUnseenPhotosUpdatedNotificationName
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(joinableStrandsUpdated:)
                                                 name:DFStrandJoinableStrandsNearbyNotificationName
                                               object:nil];
  }
  return self;
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    self.view.backgroundColor = [UIColor blackColor];
    self.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.showsCameraControls = NO;
    self.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
    self.cameraOverlayView = self.customCameraOverlayView;
    [self.customCameraOverlayView updateUIForFlashMode:UIImagePickerControllerCameraFlashModeAuto];
  } else {
    self.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
  }
  
  self.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  DDLogVerbose(@"VIEWWILLAPPEAR %@ viewDidAppear", [self class]);

  [super viewWillAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:YES];
  [self updateUnseenCount];
}

- (void)updateUnseenCount
{
  int unseenCount =  [[DFStrandsManager sharedStrandsManager] numUnseenPhotos];
  NSString *unseenCountString = [NSString stringWithFormat:@"%d", unseenCount];
  if (![self.customCameraOverlayView.galleryButton.titleLabel.text isEqualToString:unseenCountString]) {
    if (unseenCount > 0) {
      self.customCameraOverlayView.galleryButton.titleLabel.textColor = [UIColor orangeColor];
      [self.customCameraOverlayView.galleryButton setTitle:unseenCountString forState:UIControlStateNormal];
    } else {
      self.customCameraOverlayView.galleryButton.titleLabel.textColor = [UIColor orangeColor];
      [self.customCameraOverlayView.galleryButton setTitle:@"" forState:UIControlStateNormal];
    }
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self updateUnseenCount];
  [self startLocationUpdates];
  [self showHelpTextIfNeeded];
  
  DDLogVerbose(@"VIEWDIDAPPEAR %@ viewDidAppear", [self class]);
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}


- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self stopLocationUpdates];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)configureLocationManager
{
  self.locationManager = [[CLLocationManager alloc] init];
  self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  self.locationManager.distanceFilter = 10;
  self.locationManager.delegate = self;
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

#pragma mark - User actions

- (void)takePhotoButtonPressed:(UIButton *)sender
{
  [self takePicture];
  [self flashCameraView];
  [self hideNuxLabels];
}

- (void)hideNuxLabels
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
}

- (void)galleryButtonPressed:(UIButton *)sender
{
  [(RootViewController *)self.view.window.rootViewController showGallery];
}

- (void)flashButtonPressed:(UIButton *)flashButton
{
  UIImagePickerControllerCameraFlashMode newMode;
  if ([flashButton.titleLabel.text isEqualToString:FlashAutoTitle]) {
    newMode = UIImagePickerControllerCameraFlashModeOn;
  } else if ([flashButton.titleLabel.text isEqualToString:FlashOnTitle]) {
    newMode = UIImagePickerControllerCameraFlashModeOff;
  } else if ([flashButton.titleLabel.text isEqualToString:FlashOffTitle]) {
    newMode = UIImagePickerControllerCameraFlashModeAuto;
  }
  
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

- (void)lastPhotoButtonPressed:(id)sender
{
  NSArray *takenPhotos = [[[DFPhotoStore sharedStore] mostRecentPhotos:100] photosByDateAscending:YES];
  if (takenPhotos.count == 0) return;
  
  DFMultiPhotoViewController *mpvc = [[DFMultiPhotoViewController alloc]
                                      init];
  [mpvc setActivePhoto:[takenPhotos lastObject] inPhotos:takenPhotos];
  
  // Creating a nav controller and pushing it modally is a bit of a hack, but just calling
  // [self pushViewController] results in not getting viewWillAppear/didAppear on return,
  // and trying to manually send them resulted in strange bugs so this seems like the lesser
  // of two evils
  UINavigationController *photoNav = [[UINavigationController alloc] initWithRootViewController:mpvc];
  mpvc.navigationItem.title = @"My Photos";
  mpvc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                           target:photoNav
                                           action:@selector(dismissModalViewControllerAnimated:)];
  [self presentViewController:photoNav animated:YES completion:nil];
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:NO];
}

- (void)flashCameraView
{
  [UIView animateWithDuration:0.1 animations:^{
    self.cameraOverlayView.backgroundColor = [UIColor whiteColor];
  } completion:^(BOOL finished) {
    if (finished) [UIView animateWithDuration:0.1 animations:^{
      self.cameraOverlayView.backgroundColor = [UIColor clearColor];
    }];
  }];
}

#pragma mark - Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
  DDLogVerbose(@"Image picked, info: %@", info.description);
  
  if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToSave;
    
    // Handle a still image capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
      
      editedImage = (UIImage *) [info objectForKey:
                                 UIImagePickerControllerEditedImage];
      originalImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerOriginalImage];
      
      if (editedImage) {
        imageToSave = editedImage;
      } else {
        imageToSave = originalImage;
      }
      
      NSDictionary *metadata = (NSDictionary *)info[UIImagePickerControllerMediaMetadata];
      [self saveImage:imageToSave withMetadata:metadata];
      [[DFUploadController sharedUploadController] uploadPhotos];
      [DFAnalytics logPhotoTakenWithCamera:self.cameraDevice flashMode:self.cameraFlashMode];
    }
  }
}

- (void)saveImage:(UIImage *)image withMetadata:(NSDictionary *)metadata
{
  CLLocation *location = self.locationManager.location;
  NSMutableDictionary *mutableMetadata = metadata.mutableCopy;
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
  
  NSMutableDictionary *exifDict = [metadata[@"{Exif}"] mutableCopy];
  
  NSDictionary *cachedLatlongDict = @{@"CachedLatitude": @(fabs(cachedCoords.latitude)),
                                      @"CachedLatitudeRef" : cachedCoords.latitude >= 0.0 ? @"N" : @"S",
                                      @"CachedLongitude" : @(fabs(cachedCoords.longitude)),
                                      @"CachedLongitudeRef" : cachedCoords.longitude >= 0.0 ? @"E" : @"W",
                                      @"CachedDateTimeRecorded" : [[NSDateFormatter DjangoDateFormatter] stringFromDate:lastCachedLocation.timestamp],
                                      @"GPSTagDateTimeRecored" : [[NSDateFormatter DjangoDateFormatter] stringFromDate:self.locationManager.location.timestamp],
                                      };
  exifDict[@"UserComment"] = cachedLatlongDict.description;
  metadata[@"{Exif}"] = exifDict;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
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
  [self.customCameraOverlayView.takePhotoButton
   setImage:newImage
   forState:UIControlStateNormal];
}


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  CLLocation *location = locations.lastObject;
  DDLogInfo(@"DFCameraViewContrller updated location: [%f, %f]",
            location.coordinate.latitude,
            location.coordinate.longitude);
}

- (DFPeanutLocationAdapter *)locationAdapter
{
  if (!_locationAdapter) {
    _locationAdapter = [[DFPeanutLocationAdapter alloc] init];
  }
  
  return _locationAdapter;
}


@end
