//
//  DFAVCameraViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFAVCameraViewController;

@protocol DFAVCameraViewControllerDelegate <NSObject>

@required
- (void)cameraView:(DFAVCameraViewController *)cameraView
   didCaptureImage:(UIImage *)image
          metadata:(NSDictionary *)metadata;

@end



@interface DFAVCameraViewController : UIViewController

@property (nonatomic, retain) UIView *cameraOverlayView;
@property (nonatomic, retain) NSObject<DFAVCameraViewControllerDelegate> *delegate;
@property (nonatomic) UIImagePickerControllerCameraDevice cameraDevice;
@property (nonatomic) UIImagePickerControllerCameraFlashMode cameraFlashMode;
@property (nonatomic) UIImagePickerControllerSourceType sourceType;



- (void)takePicture;

@end
