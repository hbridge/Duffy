//
//  DFCameraViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraViewController.h"
#import "DFCameraOverlayView.h"
#import "RootViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFDataHasher.h"
#import "DFUploadController.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFStrandConstants.h"

@interface DFCameraViewController ()

@property (nonatomic, retain) CLLocationManager *locationManager;

@end

@implementation DFCameraViewController

@synthesize customCameraOverlayView = _customCameraOverlayView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [self configureLocationManager];
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

  self.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:YES];
  [self updateUnseenCount];
}

- (void)updateUnseenCount
{
  NSNumber *unseenCount = [[NSUserDefaults standardUserDefaults]
                           objectForKey:DFStrandUnseenCountDefaultsKey];
  if (unseenCount.intValue > 0) {
    self.customCameraOverlayView.galleryButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.customCameraOverlayView.galleryButton.titleLabel.text = [unseenCount stringValue];
  } else {
    self.customCameraOverlayView.galleryButton.titleLabel.text = @"";
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self startLocationUpdates];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self stopLocationUpdates];
}

- (void)configureLocationManager
{
  self.locationManager = [[CLLocationManager alloc] init];
  self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
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

- (void)takePhotoButtonPressed:(UIButton *)sender
{
  [self takePicture];
  [self flashCameraView];
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
      
      NSMutableDictionary *metadata = [(NSDictionary *)info[UIImagePickerControllerMediaMetadata]
                                       mutableCopy];
      [self addLocationToMetadata:metadata];
      
      // Save the new image (original or edited) to the Camera Roll
      ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
      [library writeImageToSavedPhotosAlbum:imageToSave.CGImage
                                   metadata:metadata
                            completionBlock:[self writeImageCompletionBlock]
       ];
    }
  }
}

- (void)addLocationToMetadata:(NSMutableDictionary *)metadata
{
  CLLocation *location = self.locationManager.location;
  
  
  NSDate *cachedLocationDate = [[NSUserDefaults standardUserDefaults]
                                objectForKey:DFStrandLastKnownLocationRecordedDefaultsKey];
  
  
  if (location == nil && cachedLocationDate == nil) return;
  
  CLLocationCoordinate2D coords = location.coordinate;
  NSNumber *lastLatitude = [[NSUserDefaults standardUserDefaults]
                            objectForKey:DFStrandLastKnownLatitudeDefaultsKey];
  NSNumber *lastLongitude = [[NSUserDefaults standardUserDefaults]
                             objectForKey:DFStrandLastKnownLongitudeDefaultsKey];
  CLLocationCoordinate2D cachedCoords = (CLLocationCoordinate2D){lastLatitude.doubleValue, lastLongitude.doubleValue};
  
  NSDictionary *latlongDict = @{@"Latitude": @(fabs(coords.latitude)),
                                @"LatitudeRef" : coords.latitude >= 0.0 ? @"N" : @"S",
                                @"Longitude" : @(fabs(coords.longitude)),
                                @"LongitudeRef" : coords.longitude >= 0.0 ? @"E" : @"W",
                                @"Altitude" : @(location.altitude),
                                @"DateTimeRecorded" : [[NSDateFormatter DjangoDateFormatter] stringFromDate:location.timestamp],
                                @"CachedLatitude": @(fabs(cachedCoords.latitude)),
                                @"CachedLatitudeRef" : cachedCoords.latitude >= 0.0 ? @"N" : @"S",
                                @"CachedLongitude" : @(fabs(cachedCoords.longitude)),
                                @"CachedLongitudeRef" : cachedCoords.longitude >= 0.0 ? @"E" : @"W",
                                @"CachedDateTimeRecorded" : [[NSDateFormatter DjangoDateFormatter] stringFromDate:cachedLocationDate],
                                };
  
  metadata[@"{GPS}"] = latlongDict;
}
       
- (ALAssetsLibraryWriteImageCompletionBlock)writeImageCompletionBlock
{
  return ^(NSURL *assetURL, NSError *error) {
    NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
      NSData *hashData = [DFDataHasher hashDataForALAsset:asset];
      DFPhoto *newPhoto = [DFPhoto insertNewDFPhotoForALAsset:asset
                                                 withHashData:hashData
                                                     photoTimeZone:[NSTimeZone defaultTimeZone]
                                                    inContext:context];
      DDLogVerbose(@"New photo date:%@", [[NSDateFormatter DjangoDateFormatter]
                                          stringFromDate:newPhoto.creationDate]);
      
      NSError *error;
      [context save:&error];
      if (error) {
        [NSException raise:@"Could not save DB" format:@"%@", error.description];
      }
      [[DFUploadController sharedUploadController] uploadPhotos];
      
      
    } failureBlock:^(NSError *error) {
      [NSException raise:@"Could not get asset just created." format:@"%@", error.description];
    }];
  };
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
}


- (void)joinableStrandsUpdated:(NSNotification *)note
{
  NSNumber *count = note.userInfo[DFStrandJoinableStrandsCountKey];
  UIImage *newImage;
  if (count.intValue > 0) {
    newImage = [UIImage imageNamed:@"Assets/Icons/ShutterButtonHighlighted.png"];
  } else {
    newImage = [UIImage imageNamed:@"Assets/Icons/ShutterButton.png"];
  }
  [self.customCameraOverlayView.takePhotoButton
   setImage:newImage
   forState:UIControlStateNormal];
}



@end
