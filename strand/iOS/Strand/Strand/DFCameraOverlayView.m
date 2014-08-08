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
#import "DFStrandConstants.h"

@interface DFCameraOverlayView()

@property (nonatomic, retain) MMPopLabel *cameraHelpPopLabel;
@property (nonatomic, retain) MMPopLabel *cameraJoinableHelpPopLabel;
@property (nonatomic, retain) MMPopLabel *nearbyFriendsHelpPopLabel;

@end

@implementation DFCameraOverlayView

NSString *const FlashOnTitle = @"On";
NSString *const FlashOffTitle = @"Off";
NSString *const FlashAutoTitle = @"Auto";

- (void)awakeFromNib
{
  [self configureHelpTextLabels];
  self.galleryButton.titleLabel.textAlignment = NSTextAlignmentCenter;
  self.galleryButton.badgeColor = [DFStrandConstants strandGreen];
  self.galleryButton.badgeTextColor = [UIColor blackColor];
  
  [self.nearbyFriendsLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(nearbyFriendsLabelTapped:)]];
  self.nearbyFriendsLabel.userInteractionEnabled = YES;
}

- (void)configureHelpTextLabels
{
  // set appearance style
  [[MMPopLabel appearance] setLabelColor:[DFStrandConstants defaultBackgroundColor]];
  [[MMPopLabel appearance] setLabelTextColor:[UIColor whiteColor]];
  [[MMPopLabel appearance] setLabelFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14.0f]];
  [[MMPopLabel appearance] setButtonFont:[UIFont fontWithName:@"HelveticaNeue" size:14.0f]];
  
  // create the labels
  _cameraHelpPopLabel = [MMPopLabel popLabelWithText:
            @"Take a picture to share it with nearby friends."];
  _cameraJoinableHelpPopLabel = [MMPopLabel
                                 popLabelWithText:@"Someone's taken a photo near you."
                                 "\nTake a photo to see it and share yours."];
  
  // add add them to the view
  [self addSubview:_cameraHelpPopLabel];
  [self addSubview:_cameraJoinableHelpPopLabel];
}

- (void)showHelpText
{
  [_cameraHelpPopLabel popAtView:self.takePhotoButton animatePopLabel:YES animateTargetView:NO];
}

- (void)hideHelpText
{
  [_cameraHelpPopLabel dismiss];
}

- (void)showJoinableHelpText
{
  [_cameraJoinableHelpPopLabel popAtView:self.takePhotoButton animatePopLabel:YES animateTargetView:NO];
}

- (void)hideJoinableHelpText
{
  [_cameraJoinableHelpPopLabel dismiss];
}

- (void)updateUIForFlashMode:(UIImagePickerControllerCameraFlashMode)flashMode
{
  [self.flashButton setTitle:@"" forState:UIControlStateNormal];
  if (flashMode == UIImagePickerControllerCameraFlashModeOn) {
    //[self.flashButton setTitle:@"On" forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashOnButton.png"]
                      forState:UIControlStateNormal];
  } else if (flashMode == UIImagePickerControllerCameraFlashModeOff) {
    //[self.flashButton setTitle:@"Off" forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashOffButton.png"]
                      forState:UIControlStateNormal];
  } else if (flashMode == UIImagePickerControllerCameraFlashModeAuto) {
    //[self.flashButton setTitle:@"Auto" forState:UIControlStateNormal];
    [self.flashButton setImage:[UIImage imageNamed:@"/Assets/Icons/FlashAutoButton.png"]
                      forState:UIControlStateNormal];
    
  }
}

- (void)setNearbyFriendsHelpText:(NSString *)text
{
  if (_nearbyFriendsHelpPopLabel) {
    [_nearbyFriendsHelpPopLabel removeFromSuperview];
  }
  
  if (text && ![text isEqualToString:@""]) {
    _nearbyFriendsHelpPopLabel = [MMPopLabel popLabelWithText:text];
    [self addSubview:_nearbyFriendsHelpPopLabel];
  }
}

- (void)nearbyFriendsLabelTapped:(id)sender
{
  DDLogVerbose(@"Nearby friends tapped");
  if (_nearbyFriendsHelpPopLabel && _nearbyFriendsHelpPopLabel.hidden) {
    [_nearbyFriendsHelpPopLabel popAtView:self.nearbyFriendsLabel
                          animatePopLabel:YES
                        animateTargetView:NO];
  } else if (_nearbyFriendsHelpPopLabel && !(_nearbyFriendsHelpPopLabel.isHidden)) {
    [_nearbyFriendsHelpPopLabel dismiss];
  }
}

- (void)setGalleryButtonCount:(NSUInteger)count
{
  self.galleryButton.badgeCount = (int)count;
}

@end
