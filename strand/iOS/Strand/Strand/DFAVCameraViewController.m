//
//  DFAVCameraViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAVCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "UIImage+DFHelpers.h"
#import "SAMGradientView.h"
#import "UIView+DFExtensions.h"
#import "DBMotionManager.h"


@interface DFAVCameraViewController ()

@property (atomic, retain) AVCaptureSession *session;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *capturePreviewLayer;
@property (nonatomic, retain) UIView *capturePreviewView;

@property (readonly, nonatomic, retain) AVCaptureDevice *currentCaptureDevice;
@property (nonatomic, retain) DBMotionManager *motionManager;
@property (nonatomic) UIDeviceOrientation deviceOrientation;

@end

@implementation DFAVCameraViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self createCaptureSession];
  [self.session startRunning];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  // TODO possibly guard against black screen by checking for a video connection like in takePicture
  
  if (TARGET_IPHONE_SIMULATOR) {
    [self showRandomGradientView];
  }

  if (!TARGET_IPHONE_SIMULATOR) {
  __weak typeof(self) weakSelf = self;
    [[DBMotionManager sharedManager] startMotionHandler];
    [[DBMotionManager sharedManager] setMotionRotationHandler:^(UIDeviceOrientation orientation){
      [weakSelf rotationChanged:orientation];
    }];
  }
}

- (void)appWillEnterForeground:(NSNotification *)note
{
  AVCaptureStillImageOutput *output = self.session.outputs.lastObject;
  AVCaptureConnection *videoConnection = output.connections.lastObject;
  
  DDLogInfo(@"%@ appWillEnterForeground. CaptureSessionNil:%@ VideoConnectionNil:%@ running:%@ interrupted:%@ appState:%@",
            [self.class description],
            @(self.session == nil),
            @(videoConnection == nil),
            @(self.session.isRunning),
            @(self.session.isInterrupted),
            @([[UIApplication sharedApplication] applicationState]));
  
  if (!self.session) [self createCaptureSession];
  if (!self.session.isRunning) [self.session startRunning];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  if (self.session && !self.session.isRunning) {
    [self.session startRunning];
  }
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)showRandomGradientView
{
  if (self.capturePreviewView) {
    [self.capturePreviewView removeFromSuperview];
  }

  SAMGradientView *gradientView = [[SAMGradientView alloc] initWithFrame:self.view.frame];
  srand48(time(0));

  gradientView.gradientColors = @[
                                  [UIColor colorWithRed:drand48()
                                                  green:drand48()
                                                   blue:drand48()
                                                  alpha:1.0],
                                  [UIColor colorWithRed:drand48()
                                                  green:drand48()
                                                   blue:drand48()
                                                  alpha:1.0]
                                  ];

  [self.view insertSubview:gradientView atIndex:0];
  self.capturePreviewView = gradientView;
}

- (void)createCaptureSession
{
  if (TARGET_IPHONE_SIMULATOR) {
    return;
    [self showRandomGradientView];
  }
  
  DDLogInfo(@"%@ creating new capture session.", [self.class description]);
  
  // remove old session and views if necessary
  if (self.session) [self.session stopRunning];
  if (self.capturePreviewLayer) [self.capturePreviewLayer removeFromSuperlayer];
  if (self.capturePreviewView) [self.capturePreviewView removeFromSuperview];
  
  AVCaptureSession *oldSession = self.session;
  // create a new session
  self.session = [[AVCaptureSession alloc] init];
  if ([self.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput
                                   deviceInputWithDevice:[self rearCamera]
                                   error:&error];
    assert(input);
    [self.session addInput:input];
    
    [self configureRearCamera];
    
    //preview layer
    self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.capturePreviewLayer.frame = self.view.frame;
    self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    //preview view
    self.capturePreviewView = [[UIView alloc] initWithFrame:self.view.frame];
    [self.view insertSubview:self.capturePreviewView atIndex:0];
    [self.capturePreviewView.layer addSublayer:self.capturePreviewLayer];
    
    // still image output
    AVCaptureStillImageOutput *stillOutput = [[AVCaptureStillImageOutput alloc] init];
    stillOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
    [self.session addOutput:stillOutput];
    
    [self observeNotificationsForSession:self.session oldSession:oldSession];
  }
}



- (void)configureRearCamera
{
  AVCaptureDevice *device = [self rearCamera];
  
  NSError *error;
  [device lockForConfiguration:&error];
  if (!error) {
    //turn on point autofocus for center
    if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
      [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
      [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    }
    if ([device isLowLightBoostSupported]) {
      [device setAutomaticallyEnablesLowLightBoostWhenAvailable:YES];
    }
  }
  [device unlockForConfiguration];
}

- (void)observeNotificationsForSession:(AVCaptureSession *)session oldSession:(AVCaptureSession *)oldSession
{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVCaptureSessionRuntimeErrorNotification
                                                object:oldSession];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveCaptureError:)
                                               name:AVCaptureSessionRuntimeErrorNotification
                                             object:session];
  for (NSString *notificationType in @[AVCaptureSessionDidStartRunningNotification,
                                       AVCaptureSessionDidStopRunningNotification,
                                       AVCaptureSessionWasInterruptedNotification,
                                       AVCaptureSessionInterruptionEndedNotification]) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationType object:oldSession];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveCaptureNotification:)
                                                 name:notificationType
                                               object:session];
  }
}


- (void)takePicture {
  if (TARGET_IPHONE_SIMULATOR) {
    if ([self.delegate respondsToSelector:@selector(cameraView:didCaptureImage:metadata:)]) {
      [self.delegate cameraView:self
                didCaptureImage:[self.capturePreviewView imageRepresentation]
                       metadata:nil];
      [self showRandomGradientView];
    }
    return;
  }
  
  AVCaptureStillImageOutput *output = self.session.outputs.lastObject;
  AVCaptureConnection *videoConnection = output.connections.lastObject;
  if (!videoConnection) {
    DDLogError(@"%@ takePicture: error no video connection.", [self.class description]);
    return;
  }
  
  [output
   captureStillImageAsynchronouslyFromConnection:videoConnection
   completionHandler:^(CMSampleBufferRef imageDataSampleBuffer,
                       NSError *error) {
     if (!imageDataSampleBuffer || error) return;
     
     @autoreleasepool {
       NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
       UIImage *image = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage]
                                            scale:1.0f
                                      orientation:[self currentImageOrientation]];
       
       NSNumber *number = (__bridge  NSNumber *)CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyOrientation, NULL);
       DDLogInfo(@"orientation %@", number);
       NSMutableDictionary *exifDict = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)CMGetAttachment(imageDataSampleBuffer,
                                                               kCGImagePropertyExifDictionary,
                                                               NULL)];
       exifDict[@"DateTimeOriginal"] = [[NSDateFormatter EXIFDateFormatter]
                                        stringFromDate:[NSDate date]];
       NSDictionary *metadata = @{
                                  @"Orientation": @([image CGImageOrientation]),
                                  @"{Exif}": exifDict,
                                  };
       
       if ([self.delegate respondsToSelector:@selector(cameraView:didCaptureImage:metadata:)]) {
         [self.delegate cameraView:self didCaptureImage:image metadata:metadata];
       }
     }
   }];
}

- (UIImageOrientation)currentImageOrientation {
  UIDeviceOrientation deviceOrientation = self.deviceOrientation;
  UIImageOrientation imageOrientation = UIImageOrientationRight;
  
  switch (deviceOrientation) {
    case UIDeviceOrientationLandscapeLeft:
      imageOrientation = UIImageOrientationUp;
      break;
      
    case UIDeviceOrientationLandscapeRight:
      imageOrientation = UIImageOrientationDown;
      break;
      
    case UIDeviceOrientationPortraitUpsideDown:
      imageOrientation = UIImageOrientationLeft;
      break;
      
    default:
      break;
  }

  return imageOrientation;
}


- (void)setCameraOverlayView:(UIView *)cameraOverlayView
{
  if (self.cameraOverlayView) [self.cameraOverlayView removeFromSuperview];
  _cameraOverlayView = cameraOverlayView;
  
  if (!TARGET_IPHONE_SIMULATOR) {
  //Focus gesture
    UITapGestureRecognizer *focusTapRecognizer = [[UITapGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(previewTapped:)];
    [_cameraOverlayView addGestureRecognizer:focusTapRecognizer];
  }
  
  [self.view addSubview:_cameraOverlayView];
}

- (void)previewTapped:(UITapGestureRecognizer *)tapRecognizer
{
  CGPoint viewLocation = [tapRecognizer locationInView:self.capturePreviewView];
  CGPoint deviceLocation = [self.capturePreviewLayer captureDevicePointOfInterestForPoint:viewLocation];
  DDLogVerbose(@"Focus tapped. Location in view: %@ focusLocation: %@",
               NSStringFromCGPoint(viewLocation),
               NSStringFromCGPoint(deviceLocation));
  
  if ([self.currentCaptureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
    NSError *error;
    [self.currentCaptureDevice lockForConfiguration:&error];
    if (!error) {
      if ([self.currentCaptureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus])
        [self.currentCaptureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
      if ([self.currentCaptureDevice isFocusPointOfInterestSupported])
        [self.currentCaptureDevice setFocusPointOfInterest:deviceLocation];
      [self.currentCaptureDevice unlockForConfiguration];
    } else {
      DDLogError(@"%@ couldn't get lock to set focus POI: %@", [self.class description], error.description);
    }
  } else {
    DDLogWarn(@"%@ autofocus mode not supported.", [self.class description]);
  }
  
  if ([self.currentCaptureDevice isExposurePointOfInterestSupported]) {
    NSError *error;
    [self.currentCaptureDevice lockForConfiguration:&error];
    if (!error) {
      if ([self.currentCaptureDevice  isExposureModeSupported:AVCaptureExposureModeAutoExpose])
        [self.currentCaptureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
      if ([self.currentCaptureDevice isExposurePointOfInterestSupported])
        [self.currentCaptureDevice setExposurePointOfInterest:deviceLocation];
      [self.currentCaptureDevice unlockForConfiguration];
    } else {
      DDLogError(@"%@ couldn't get lock to set exposure POI: %@", [self.class description], error.description);
    }
  } else {
    DDLogInfo(@"%@ exposure POI not supported.", [self.class description]);
  }
}

- (void)setCameraFlashMode:(UIImagePickerControllerCameraFlashMode)cameraFlashMode
{
  AVCaptureFlashMode newMode;
  if (cameraFlashMode == UIImagePickerControllerCameraFlashModeOn) {
    newMode = AVCaptureFlashModeOn;
  } else if (cameraFlashMode == UIImagePickerControllerCameraFlashModeOff) {
    newMode = AVCaptureFlashModeOff;
  } else {
    newMode = AVCaptureFlashModeAuto;
  }
  
  if ([self.currentCaptureDevice isFlashModeSupported:newMode]) {
    NSError *error;
    [self.currentCaptureDevice lockForConfiguration:&error];
    self.currentCaptureDevice.flashMode = newMode;
    [self.currentCaptureDevice unlockForConfiguration];
  }
}

- (UIImagePickerControllerCameraFlashMode)cameraFlashMode
{
  if (self.currentCaptureDevice.flashMode == AVCaptureFlashModeOn) {
    return UIImagePickerControllerCameraFlashModeOn;
  } else if (self.currentCaptureDevice.flashMode == AVCaptureFlashModeOff) {
    return UIImagePickerControllerCameraFlashModeOff;
  } else if (self.currentCaptureDevice.flashMode == AVCaptureFlashModeAuto) {
    return UIImagePickerControllerCameraFlashModeAuto;
  }
  
  return UIImagePickerControllerCameraFlashModeAuto;
}

- (void)setCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice
{
  DDLogVerbose(@"%@ setting new camera device to %@",
               [self.class description],
               @(cameraDevice));
  AVCaptureDeviceInput *oldInput = self.session.inputs.firstObject;
  [self.session removeInput:oldInput];
  
  NSError *error = nil;
  AVCaptureDeviceInput *newInput;
  if (cameraDevice == UIImagePickerControllerCameraDeviceRear) {
    newInput = [AVCaptureDeviceInput deviceInputWithDevice:[self rearCamera] error:&error];
  } else {
    newInput = [AVCaptureDeviceInput deviceInputWithDevice:[self frontCamera] error:&error];
  }
  
  if (!newInput || error) {
    DDLogError(@"%@ couldn't set new camera device to %@.  Error:%@",
               [self.class description],
               @(cameraDevice),
               error);
    return;
  }

  [self.session addInput:newInput];
}

- (UIImagePickerControllerCameraDevice)cameraDevice
{
  if (self.currentCaptureDevice == [self frontCamera]) {
    return UIImagePickerControllerCameraDeviceFront;
  }
  
  return UIImagePickerControllerCameraDeviceRear;
}


- (AVCaptureDevice *)frontCamera {
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in devices) {
    if (device.position == AVCaptureDevicePositionFront) {
      return device;
    }
  }
  return nil;
}

- (AVCaptureDevice *)rearCamera {
  return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}


- (AVCaptureDevice *)currentCaptureDevice {
  return [(AVCaptureDeviceInput *)self.session.inputs.firstObject device];
}


- (void)didReceiveCaptureError:(NSNotification *)note
{
  DDLogError(@"%@ capture error: %@", [self.class description],
             [(NSError *)note.userInfo[AVCaptureSessionErrorKey] description]);
}

- (void)didReceiveCaptureNotification:(NSNotification *)note
{
  DDLogInfo(@"%@ %@", [self.class description], note.name);
}

- (void) rotationChanged:(UIDeviceOrientation) orientation
{
  if ( orientation != UIDeviceOrientationUnknown ||
      orientation != UIDeviceOrientationFaceUp ||
      orientation != UIDeviceOrientationFaceDown ) {
    _deviceOrientation = orientation;
  }
}


@end
