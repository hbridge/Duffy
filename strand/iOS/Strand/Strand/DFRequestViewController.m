//
//  DFRequestNotificationView.m
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRequestViewController.h"
#import "DFImageManager.h"

@implementation DFRequestViewController

@synthesize inviteFeedObject = _inviteFeedObject;

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.view.frame = self.frame;
  [self.view layoutIfNeeded];
  self.profileWithContextView.titleLabel.textColor = [UIColor whiteColor];
  self.profileWithContextView.subtitleLabel.textColor = [UIColor whiteColor];
  self.gradientView.backgroundColor = [UIColor clearColor];
  self.gradientView.gradientColors = @[
                                       [UIColor blackColor],
                                       [UIColor clearColor],
                                       ];
}

- (void)setFrame:(CGRect)frame
{
  _frame = frame;
  self.view.frame = frame;
  [self.view layoutIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self configureWithInviteFeedObject:self.inviteFeedObject];
}


- (IBAction)selectButtonPressed:(id)sender {
  if (self.selectButtonHandler) self.selectButtonHandler();
}

- (void)setInviteFeedObject:(DFPeanutFeedObject *)inviteFeedObject
{
  _inviteFeedObject = inviteFeedObject;
  //[self configureWithInviteFeedObject:inviteFeedObject];
}

- (void)configureWithInviteFeedObject:(DFPeanutFeedObject *)inviteFeedObject
{
  if (!self.view) return;
  DFPeanutFeedObject *sectionObject = [[inviteFeedObject descendentdsOfType:DFFeedObjectSection]firstObject];
  self.profileWithContextView.profileStackView.peanutUsers = inviteFeedObject.actors;
  self.profileWithContextView.titleLabel.text = [NSString stringWithFormat:@"%@ requested photos",
                                                 inviteFeedObject.actorNames.firstObject];
  self.profileWithContextView.subtitleLabel.text = sectionObject.placeAndRelativeTimeString;
  DFPeanutFeedObject *suggestionsObject = [[inviteFeedObject subobjectsOfType:DFFeedObjectSuggestedPhotos] firstObject];
  DFPeanutFeedObject *firstPhoto = [[suggestionsObject leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  [[DFImageManager sharedManager]
   imageForID:firstPhoto.id
   pointSize:self.imageView.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeHighQualityFormat
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       self.imageView.image = image;
       [self.imageView setNeedsLayout];
     });
   }];

}


@end
