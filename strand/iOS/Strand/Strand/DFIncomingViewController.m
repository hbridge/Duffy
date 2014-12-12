//
//  DFIncomingViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFIncomingViewController.h"
#import <Slash/Slash.h>
#import "DFImageManager.h"

@interface DFIncomingViewController ()

@end

@implementation DFIncomingViewController


- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                       inStrand:(DFStrandIDType)strandID
                     fromSender:(DFPeanutUserObject *)peanutUser
{
  self = [super init];
  if (self) {
    _photoID = photoID;
    _strandID = strandID;
    _sender = peanutUser;
  }
  return self;
}

- (instancetype)initWithNuxStep:(NSUInteger)nuxStep
{
  self = [super init];
  if (self) {
    self.nuxStep = nuxStep;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureProfileWithContext];
  [self configureSwipableButtonView];
}

- (void)configureProfileWithContext
{
  self.profileWithContextView.profileStackView.profilePhotoWidth = 45.0;
  if (self.nuxStep) {
    self.profileWithContextView.profileStackView.maxAbbreviationLength = 2;
    [self.profileWithContextView.profileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
    [self.profileWithContextView setTitleMarkup:[NSString stringWithFormat:@"<name>%@</name> sent you a photo",
                                         @"Team Swap"]];
  } else {
    [self.profileWithContextView.profileStackView setPeanutUser:self.sender];
    [self.profileWithContextView setTitleMarkup:[NSString
                                                 stringWithFormat:@"<name>%@</name> sent you a photo",
                                                 self.sender.firstName]];
  }
  [self.profileWithContextView.subtitleLabel removeFromSuperview];
}

- (void)configureSwipableButtonView
{
  self.swipableButtonView.delegate = self;
  [self.swipableButtonView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingSkipButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.otherButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingCommentButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingLikeButtonIcon"]
   forState:UIControlStateNormal];
  for (UIButton *button in @[self.swipableButtonView.noButton,
                             self.swipableButtonView.otherButton,
                             self.swipableButtonView.yesButton]) {
    [button setTitle:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor]; 
  }
  
  [self.swipableButtonView configureToUseImage];
  
}

- (void)viewDidLayoutSubviews
{
  if (self.nuxStep) {
    self.swipableButtonView.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
    [[DFImageManager sharedManager]
     imageForID:self.photoID
     pointSize:self.swipableButtonView.centerView.frame.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         self.swipableButtonView.imageView.image = image;
       });
     }];
  }
}

- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
                 buttonSelected:(UIButton *)button
{
  if (button == self.swipableButtonView.noButton) {
    if (self.nextHandler) self.nextHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonView.otherButton) {
    if (self.commentHandler) self.commentHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonView.yesButton) {
    if (self.likeHandler) self.likeHandler(self.photoID, self.strandID);
  }
}

@end
