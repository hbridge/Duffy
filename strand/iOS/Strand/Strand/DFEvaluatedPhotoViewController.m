//
//  DFEvaluatedPhotoViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFEvaluatedPhotoViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFImageManager.h"

@interface DFEvaluatedPhotoViewController ()

@property (nonatomic) DFActionID userLikeActionID;

@end

@implementation DFEvaluatedPhotoViewController

@synthesize userLikeActionID = _userLikeActionID;


- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject inPostsObject:(DFPeanutFeedObject *)postsObject
{
  self = [super initWithPhotoObject:photoObject inPostsObject:postsObject];
  if (self) {
    self.openKeyboardOnAppear = NO;
    _userLikeActionID = [[[self.photoObject userFavoriteAction] id] longLongValue];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self configureProfileWithContext];
  [self configureToolbar];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureProfileWithContext
{
  for (DFProfileStackView *psv in @[self.senderProfileStackView, self.recipientsProfileStackView]) {
    psv.backgroundColor = [UIColor clearColor];
    psv.nameMode = DFProfileStackViewNameShowAlways;
  }
  
  DFPeanutFeedObject *strandPost = self.postsObject.objects.firstObject;
  DFPeanutUserObject *sender = strandPost.actors.firstObject;
  self.senderProfileStackView.profilePhotoWidth = 50.0;
  [self.senderProfileStackView setPeanutUser:sender];

  self.recipientsProfileStackView.profilePhotoWidth = 35.0;
  NSArray *recipients = [self.postsObject.actors arrayByRemovingObject:sender];
  [self.recipientsProfileStackView setPeanutUsers:recipients];
}

- (void)configureToolbar
{
  self.textFieldItem.width = self.toolbar.frame.size.width - self.sendButton.width - 36 - self.likeBarButtonItem.width - 36;
  [self setLikeBarButtonItemOn:(self.userLikeActionID > 0)];
}

- (void)setLikeBarButtonItemOn:(BOOL)on
{
  if (on) {
    self.likeBarButtonItem.image = [UIImage imageNamed:@"Assets/Icons/LikeOnToolbarIcon"];
  } else {
    self.likeBarButtonItem.image = [UIImage imageNamed:@"Assets/Icons/LikeOffToolbarIcon"];
  }
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  [self configureToolbar];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  CGFloat aspectRatio = self.photoObject.full_height.floatValue / self.photoObject.full_width.floatValue;
  CGRect frame = CGRectMake(10,
                            0,
                            self.view.frame.size.width - 20,
                            (self.view.frame.size.width - 20) * aspectRatio);
  if (!self.imageView) {
    self.imageView = [[UIImageView alloc] initWithFrame:frame];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
  } else {
    self.imageView.frame = frame;
  }
  
  [[DFImageManager sharedManager]
   imageForID:self.photoObject.id
   pointSize:self.imageView.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       self.imageView.image = image;
     });
   }];
  [self.tableView setTableHeaderView:self.imageView];
}



- (IBAction)likeItemPressed:(id)sender {
  BOOL newLikeValue = (self.userLikeActionID == 0);
  DFActionID oldID = self.userLikeActionID;
  self.userLikeActionID = newLikeValue;
  [[DFPeanutFeedDataManager sharedManager]
   setLikedByUser:newLikeValue
   photo:self.photoObject.id
   inStrand:self.photoObject.strand_id.longLongValue
   oldActionID:oldID
   success:^(DFActionID actionID) {
     self.userLikeActionID = actionID;
   } failure:^(NSError *error) {
     
   }];

}

- (void)setUserLikeActionID:(DFActionID)userLikeActionID
{
  _userLikeActionID = userLikeActionID;
  [self configureToolbar];
}

@end
