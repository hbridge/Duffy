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
  [[DFImageManager sharedManager]
   imageForID:self.photoID
   pointSize:self.swipableButtonImageView.imageView.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
   completion:^(UIImage *image) {
     self.swipableButtonImageView.imageView.image = image;
   }];
}

@end
