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
  CGPoint location = [tapRecognizer locationInView:self.capturePreviewView];
  CGPoint focusLocation = [self.capturePreviewLayer captureDevicePointOfInterestForPoint:location];
  DDLogVerbose(@"Focus tapped. Location in view: %@ focusLocation: %@",
               NSStringFromCGPoint(location),
               NSStringFromCGPoint(focusLocation));
  
  NSError *error;
  [[self currentCameraDevice] lockForConfiguration:&error];
  [[self currentCameraDevice] setFocusMode:AVCaptureFocusModeAutoFocus];
  [[self currentCameraDevice] setFocusPointOfInterest:focusLocation];
  [[self currentCameraDevice] unlockForConfiguration];
  if (error) {
    DDLogError(@"%@ couldn't set focus POI: %@", [self.class description], error.description);
  }
}


- (AVCaptureDevice *)currentCameraDevice {
  return [(AVCaptureDeviceInput *)self.session.inputs.firstObject device];
}


@end
