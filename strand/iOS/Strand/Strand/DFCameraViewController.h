//
//  DFCameraViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFCameraOverlayView;

@interface DFCameraViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
- (IBAction)cameraButtonPressed:(UIButton *)sender;

@property (nonatomic, readonly, retain) DFCameraOverlayView *cameraOverlayView;
@property (nonatomic, readonly, retain) UIImagePickerController *imagePickerController;

@end
