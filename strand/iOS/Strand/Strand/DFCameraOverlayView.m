//
//  DFCameraOverlayView.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraOverlayView.h"

@implementation DFCameraOverlayView

NSString *const FlashOnTitle = @"On";
NSString *const FlashOffTitle = @"Off";
NSString *const FlashAutoTitle = @"Auto";

- (void)awakeFromNib
{
  self.flashButton.imageView.image = [self.flashButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)updateUIForFlashMode:(UIImagePickerControllerCameraFlashMode)flashMode
{
  if (flashMode == UIImagePickerControllerCameraFlashModeOn) {
    [self.flashButton setTitle:@"On" forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashOnButton.png"]
                      forState:UIControlStateNormal];
  } else if (flashMode == UIImagePickerControllerCameraFlashModeOff) {
    [self.flashButton setTitle:@"Off" forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashOffButton.png"]
                      forState:UIControlStateNormal];
  } else if (flashMode == UIImagePickerControllerCameraFlashModeAuto) {
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashOnButton.png"]
                      forState:UIControlStateNormal];
    [self.flashButton setTitle:@"Auto" forState:UIControlStateNormal];
  }

}

@end
