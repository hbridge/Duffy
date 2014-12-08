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

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureProfileWithContext];
  [self configureSwipableButtonImageView];
}

- (void)configureProfileWithContext
{
  [self.profileWithContextView.profileStackView setPeanutUser:self.sender];
  self.profileWithContextView.titleLabel.text = [NSString stringWithFormat:@"%@ sent you a photo",
                                                 self.sender.firstName];
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
  }
  
  [[DFImageManager sharedManager]
   imageForID:self.photoID
   pointSize:self.swipableButtonImageView.imageView.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
   completion:^(UIImage *image) {
     self.swipableButtonImageView.imageView.image = image;
   }];
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
