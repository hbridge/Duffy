//
//  DFCameraOverlayView.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const FlashOnTitle;
extern NSString *const FlashOffTitle;
extern NSString *const FlashAutoTitle;

@interface DFCameraOverlayView : UIView
@property (weak, nonatomic) IBOutlet UIButton *takePhotoButton;
@property (weak, nonatomic) IBOutlet UIButton *galleryButton;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *swapCameraButton;

- (void)updateUIForFlashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
- (void)showHelpText;
- (void)hideHelpText;

@end
