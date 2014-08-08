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


@interface DFAVCameraViewController ()

@property (readonly, retain) AVCaptureSession *session;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *capturePreviewLayer;
@property (nonatomic, retain) UIView *capturePreviewView;

@property (nonatomic, readonly) AVCaptureDevice *currentCaptureDevice;

@end

@implementation DFAVCameraViewController

@synthesize session = _session;


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  
  [self.session startRunning];

}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (AVCaptureSession *)session
{
  if (!_session) {
    _session = [[AVCaptureSession alloc] init];
    if ([_session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
      NSLog(@"Setting session preset");
      _session.sessionPreset = AVCaptureSessionPresetPhoto;
      AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      
      NSError *error;
      AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
      assert(input);
      [_session addInput:input];
      
      //turn on point autofocus for center
      [device lockForConfiguration:&error];
      if (!error) {
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
          //device.focusPointOfInterest = CGPointMake(0.5, 0.5);
          device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        if ([device isFlashModeSupported:AVCaptureFlashModeAuto]) {
          device.flashMode = AVCaptureFlashModeAuto;
        }
      }
      [device unlockForConfiguration];
      
      //preview layer
      self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
      self.capturePreviewLayer.frame = self.view.frame;
      self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
      
      //preview view
      self.capturePreviewView = [[UIView alloc] initWithFrame:self.view.frame];
      [self.view insertSubview:self.capturePreviewView atIndex:0];
      [self.capturePreviewView.layer addSublayer:self.capturePreviewLayer];
      
      // still image output
      AVCaptureStillImageOutput *stillOutput = [[AVCaptureStillImageOutput alloc] init];
      stillOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
      [_session addOutput:stillOutput];
      
      
    }
  }
  return _session;
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
       NSDictionary *metadata = @{@"{Exif}": exifDict};
       
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
    [self.currentCaptureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
    [self.currentCaptureDevice setFocusPointOfInterest:deviceLocation];
    [self.currentCaptureDevice unlockForConfiguration];
    if (error) {
      DDLogError(@"%@ couldn't set focus POI: %@", [self.class description], error.description);
    }
  } else {
    DDLogWarn(@"%@ autofocus mode not supported.", [self.class description]);
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


@end
