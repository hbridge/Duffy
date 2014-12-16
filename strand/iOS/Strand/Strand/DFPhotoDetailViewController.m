//
//  DFEvaluatedPhotoViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoDetailViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFImageManager.h"
#import "DFPeanutNotificationsManager.h"
#import "DFInviteStrandViewController.h"

@interface DFPhotoDetailViewController ()

@property (nonatomic) DFActionID userLikeActionID;

@end

@implementation DFPhotoDetailViewController

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
  [self configureCommentToolbar];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  NSArray *actionIDs = [self.photoObject.actions arrayByMappingObjectsWithBlock:^id(DFPeanutAction *action) {
    return action.id;
  }];
  
  [[DFPeanutNotificationsManager sharedManager] markActionIDsSeen:actionIDs];
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
  self.senderProfileStackView.profilePhotoWidth = 50.0;
    self.recipientsProfileStackView.profilePhotoWidth = 35.0;
  
  if (self.nuxStep) {
    self.senderProfileStackView.maxAbbreviationLength = 2;
    [self.senderProfileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
    
    [self.recipientsProfileStackView setPeanutUser:[[DFUser currentUser] peanutUser]];
    return;
  }
  
  DFPeanutFeedObject *strandPost = self.postsObject.objects.firstObject;
  DFPeanutUserObject *sender = strandPost.actors.firstObject;
  
  [self.senderProfileStackView setPeanutUser:sender];
  [self.senderProfileStackView
   setBadgeImage:(_userLikeActionID > 0) ? [UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"] : nil
   forUser:sender];
  
  NSArray *recipients = [self.postsObject.actors arrayByRemovingObject:sender];
  [self.recipientsProfileStackView setPeanutUsers:recipients];
  for (DFPeanutUserObject *recipient in recipients) {
    if ([[self.photoObject actionsOfType:DFPeanutActionFavorite forUser:recipient.id] count] > 0) {
      [self.recipientsProfileStackView setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"]
                                           forUser:recipient];
    } else {
      [self.recipientsProfileStackView setBadgeImage:nil
                                             forUser:recipient];
    }
  }
}

- (void)configureCommentToolbar
{
  if (self.nuxStep) [self.commentToolbar removeFromSuperview];
  self.textField = self.commentToolbar.textField;
  [self.commentToolbar.profileStackView setPeanutUser:[[DFUser currentUser] peanutUser]];
  [self setLikeBarButtonItemOn:(self.userLikeActionID > 0)];
  [self.commentToolbar.likeButton addTarget:self
                                     action:@selector(likeItemPressed:)
                           forControlEvents:UIControlEventTouchUpInside];
  self.commentToolbar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
  [self.commentToolbar.sendButton
   addTarget:self
   action:@selector(sendButtonPressed:)
   forControlEvents:UIControlEventTouchUpInside];
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.commentToolbar.frame.size.height, 0);
  if (self.compressedModeEnabled) self.commentToolbar.likeButtonDisabled = YES;
}

- (void)setLikeBarButtonItemOn:(BOOL)on
{
  if (on) {
    [self.commentToolbar.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeOnToolbarIcon"] forState:UIControlStateNormal];
  } else {
    [self.commentToolbar.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeOffToolbarIcon"] forState:UIControlStateNormal];
  }
}

- (void)setCommentsExpanded:(BOOL)commentsExpanded
{
  [super setCommentsExpanded:commentsExpanded];
  [self configureToolbarHidden];
}

- (void)configureToolbarHidden
{
  if (self.compressedModeEnabled && [self tableView:self.tableView numberOfRowsInSection:0] == 2 && !self.commentsExpanded) {
    //self.commentToolbarHeightConstraint.constant = 0;
    self.commentToolbar.hidden = YES;
  } else {
    //self.commentToolbarHeightConstraint.constant = 52;
    self.commentToolbar.hidden = NO;
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  CGFloat aspectRatio;
  if (self.compressedModeEnabled) {
    aspectRatio = 1.0;
  } else if (self.photoObject.full_height && self.photoObject.full_width) {
    aspectRatio = self.photoObject.full_height.floatValue / self.photoObject.full_width.floatValue;
  } else {
    aspectRatio = 1.0;
  }
  CGRect frame = CGRectMake(10,
                            0,
                            self.view.frame.size.width - 20,
                            (self.view.frame.size.width - 20) * aspectRatio);
  if (!self.imageView) {
    self.imageView = [[UIImageView alloc] initWithFrame:frame];
    self.imageView.clipsToBounds = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  } else {
    self.imageView.frame = frame;
  }
  
  self.addPersonButton.hidden = self.compressedModeEnabled;
  self.tableView.separatorStyle = self.compressedModeEnabled ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
  [self configureToolbarHidden];
  
  if (self.nuxStep) {
    self.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
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
  }
  [self.tableView setTableHeaderView:self.imageView];
}

- (IBAction)likeItemPressed:(id)sender {
  BOOL newLikeValue = (self.userLikeActionID == 0);
  DFActionID oldID = self.userLikeActionID;
  self.userLikeActionID = newLikeValue;
  [self configureProfileWithContext];
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

- (IBAction)addPersonPressed:(id)sender {
  NSArray *peanutContacts = [self.postsObject.actors arrayByMappingObjectsWithBlock:^id(id input) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:input];
    return contact;
  }];
  DFInviteStrandViewController *inviteStrandController = [[DFInviteStrandViewController alloc]
                                                          initWithSuggestedPeanutContacts:nil
                                                          notSelectablePeanutContacts:peanutContacts
                                                          notSelectableReason:@"Already Member"];
  inviteStrandController.sectionObject = self.postsObject;
  [self.navigationController pushViewController:inviteStrandController animated:YES];
}

- (void)setUserLikeActionID:(DFActionID)userLikeActionID
{
  _userLikeActionID = userLikeActionID;
  [self configureCommentToolbar];
}

@end
