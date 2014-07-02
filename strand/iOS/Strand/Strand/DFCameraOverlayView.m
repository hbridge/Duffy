//
//  DFCameraOverlayView.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraOverlayView.h"
#import "MMPopLabel.h"
#import "UIImage+Resize.h"

@interface DFCameraOverlayView()

@property (nonatomic, retain) MMPopLabel *cameraHelpPopLabel;
@property (nonatomic, retain) MMPopLabel *cameraJoinableHelpPopLabel;

@end

@implementation DFCameraOverlayView

NSString *const FlashOnTitle = @"On";
NSString *const FlashOffTitle = @"Off";
NSString *const FlashAutoTitle = @"Auto";

static NSInteger LastPhotoImageSize = 100;
static NSUInteger LastPhotoImageCornerRadius = 3;

- (void)awakeFromNib
{
  self.flashButton.imageView.image = [self.flashButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [self configureHelpTextLabels];
  self.galleryButton.titleLabel.textAlignment = NSTextAlignmentCenter;
}

- (void)configureHelpTextLabels
{
  // set appearance style
  [[MMPopLabel appearance] setLabelColor:[UIColor orangeColor]];
  [[MMPopLabel appearance] setLabelTextColor:[UIColor whiteColor]];
  [[MMPopLabel appearance] setLabelTextHighlightColor:[UIColor redColor]];
  [[MMPopLabel appearance] setLabelFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14.0f]];
  [[MMPopLabel appearance] setButtonFont:[UIFont fontWithName:@"HelveticaNeue" size:14.0f]];
  
  // create the labels
  _cameraHelpPopLabel = [MMPopLabel popLabelWithText:
            @"Take a picture to share it with nearby friends."];
  _cameraJoinableHelpPopLabel = [MMPopLabel
                                 popLabelWithText:@"Someone's taken a photo nearby!"
                                 "\nTake a photo to see it and share yours."];
  
  // add add them to the view
  [self addSubview:_cameraHelpPopLabel];
  [self addSubview:_cameraJoinableHelpPopLabel];
}

- (void)showHelpText
{
  [_cameraHelpPopLabel popAtView:self.takePhotoButton];
}

- (void)hideHelpText
{
  [_cameraHelpPopLabel dismiss];
}

- (void)showJoinableHelpText
{
  [_cameraJoinableHelpPopLabel popAtView:self.takePhotoButton];
}

- (void)hideJoinableHelpText
{
  [_cameraJoinableHelpPopLabel dismiss];
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
