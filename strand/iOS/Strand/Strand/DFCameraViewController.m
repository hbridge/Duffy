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

@interface DFCameraViewController ()

@property (nonatomic, retain) CLLocationManager *locationManager;

@end

@implementation DFCameraViewController

@synthesize customCameraOverlayView = _customCameraOverlayView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {

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
    [self configureLocationManager];
  } else {
    self.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
  }
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(startLocationUpdates)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
  
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(stopLocationUpdates)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];


  self.delegate = self;
}



- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:YES];
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
  self.locationManager.pausesLocationUpdatesAutomatically = NO;
}

- (void)startLocationUpdates
{
  DDLogVerbose(@"DFCameraViewController starting location updates.");
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
  DDLogInfo(@"Image picked, info: %@", info.description);
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
  if (location == nil) return;
  
  CLLocationCoordinate2D coords = location.coordinate;
  
  NSDictionary *latlongDict = @{@"Latitude": @(fabs(coords.latitude)),
                                @"LatitudeRef" : coords.latitude >= 0.0 ? @"N" : @"S",
                                @"Longitude" : @(fabs(coords.longitude)),
                                @"LongitudeRef" : coords.longitude >= 0.0 ? @"E" : @"W",
                                @"Altitude" : @(location.altitude),
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
      [DFPhoto insertNewDFPhotoForALAsset:asset withHashData:hashData inContext:context];
      
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



@end
