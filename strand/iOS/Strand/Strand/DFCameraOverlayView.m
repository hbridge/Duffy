//
//  DFCameraOverlayView.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraOverlayView.h"
#import "MMPopLabel.h"

@interface DFCameraOverlayView()

@property (nonatomic, retain) MMPopLabel *label;

@end

@implementation DFCameraOverlayView

NSString *const FlashOnTitle = @"On";
NSString *const FlashOffTitle = @"Off";
NSString *const FlashAutoTitle = @"Auto";

- (void)awakeFromNib
{
  self.flashButton.imageView.image = [self.flashButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [self configureHelpTextLabel];
  self.galleryButton.titleLabel.textAlignment = NSTextAlignmentCenter;
}

- (void)configureHelpTextLabel
{
  // set appearance style
  [[MMPopLabel appearance] setLabelColor:[UIColor orangeColor]];
  [[MMPopLabel appearance] setLabelTextColor:[UIColor whiteColor]];
  [[MMPopLabel appearance] setLabelTextHighlightColor:[UIColor redColor]];
  [[MMPopLabel appearance] setLabelFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14.0f]];
  [[MMPopLabel appearance] setButtonFont:[UIFont fontWithName:@"HelveticaNeue" size:14.0f]];
  
  // _label is a view controller property
  _label = [MMPopLabel popLabelWithText:
            @"Take a picture to share it with nearby friends."];
  
  // add it to your view
  [self addSubview:_label];
}

- (void)showHelpText
{
  [_label popAtView:self.takePhotoButton];
}

- (void)hideHelpText
{
  [_label dismiss];
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

- (void)layoutSubviews
{
  [super layoutSubviews];
}

@end
