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


@interface DFAVCameraViewController ()

@property (atomic, retain) AVCaptureSession *session;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *capturePreviewLayer;
@property (nonatomic, retain) UIView *capturePreviewView;

@property (readonly, nonatomic, retain) AVCaptureDevice *currentCaptureDevice;

@end

@implementation DFAVCameraViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
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
}

- (void)appDidBecomeActive:(NSNotification *)note
{
  DDLogInfo(@"%@ app became active. Cature session nil:%@ running:%@ interrupted:%@",
            [self.class description],
            @(self.session == nil),
            @(self.session.isRunning),
            @(self.session.isInterrupted));
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


- (void)createCaptureSession
{
  DDLogInfo(@"%@ creating new capture session.", [self.class description]);
  
  // remove old session and views if necessary
  if (self.session) {
    
  }[self.session stopRunning];
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
  AVCaptureStillImageOutput *output = self.session.outputs.lastObject;
  AVCaptureConnection *videoConnection = output.connections.lastObject;
  if (!videoConnection) return;
  
  [output
   captureStillImageAsynchronouslyFromConnection:videoConnection
   completionHandler:^(CMSampleBufferRef imageDataSampleBuffer,
                       NSError *error) {
     if (!imageDataSampleBuffer || error) return;
     
     @autoreleasepool {
       NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
       UIImage *image = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage]
                                            scale:1.0f
                                      orientation:[self.class currentImageOrientation]];
       
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

+ (UIImageOrientation)currentImageOrientation {
  UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
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
  
  //Focus gesture
  UITapGestureRecognizer *focusTapRecognizer = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self
                                                action:@selector(previewTapped:)];
  [_cameraOverlayView addGestureRecognizer:focusTapRecognizer];
  
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
  
  NSError *error;
  [self.currentCaptureDevice lockForConfiguration:&error];
  self.currentCaptureDevice.flashMode = newMode;
  [self.currentCaptureDevice unlockForConfiguration];
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

@end
