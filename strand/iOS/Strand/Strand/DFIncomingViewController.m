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
  [self configureSwipableButtonImageView];
}

- (void)configureProfileWithContext
{
  if (self.nuxStep) {
    self.profileWithContextView.profileStackView.maxAbbreviationLength = 2;
    [self.profileWithContextView.profileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
    self.profileWithContextView.title = [NSString stringWithFormat:@"%@ sent you a photo",
                                         self.sender.firstName];
  } else {
    [self.profileWithContextView.profileStackView setPeanutUser:self.sender];
    self.profileWithContextView.title = [NSString stringWithFormat:@"%@ sent you a photo",
                                                 self.sender.firstName];
  }
  [self.profileWithContextView.subtitleLabel removeFromSuperview];
}

- (void)configureSwipableButtonImageView
{
  self.swipableButtonImageView.delegate = self;
  [self.swipableButtonImageView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingSkipButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonImageView.otherButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingCommentButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonImageView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingLikeButtonIcon"]
   forState:UIControlStateNormal];
  for (UIButton *button in @[self.swipableButtonImageView.noButton,
                             self.swipableButtonImageView.otherButton,
                             self.swipableButtonImageView.yesButton]) {
    [button setTitle:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor]; 
  }
}

- (void)viewDidLayoutSubviews
{
  if (self.nuxStep) {
    self.swipableButtonImageView.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
    [[DFImageManager sharedManager]
     imageForID:self.photoID
     pointSize:self.swipableButtonImageView.imageView.frame.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         self.swipableButtonImageView.imageView.image = image;
       });
     }];
  }
}

- (void)swipableButtonImageView:(DFSwipableButtonImageView *)swipableButtonImageView
                 buttonSelected:(UIButton *)button
{
  if (button == self.swipableButtonImageView.noButton) {
    if (self.nextHandler) self.nextHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonImageView.otherButton) {
    if (self.commentHandler) self.commentHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonImageView.yesButton) {
    if (self.likeHandler) self.likeHandler(self.photoID, self.strandID);
  }
}

@end
