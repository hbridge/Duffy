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
#import "DFNavigationController.h"
#import "DFPeanutActionAdapter.h"
#import "DFAlertController.h"
#import "DFCommentTableViewCell.h"
#import "DFAnalytics.h"
#import "DFButtonTableViewCell.h"
#import "DFNoResultsTableViewCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFPeanutNotificationsManager.h"
#import "DFPhotoStore.h"
#import "DFPeanutPhoto.h"
#import "DFFriendProfileViewController.h"
#import <MMPopLabel/MMLabel.h>
#import "UIView+DFExtensions.h"

const NSUInteger CompressedModeMaxRows = 1;

@interface DFPhotoDetailViewController ()

@property (nonatomic) DFActionID userLikeActionID;
@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (nonatomic, retain) NSMutableArray *comments;
@property (nonatomic, retain) DFCommentTableViewCell *templateCell;
@property (nonatomic, retain) DFAlertController *alertController;
@property (nonatomic, retain) NSArray *unreadActions;
@property (nonatomic, retain) DFRemoteImageView *theatreModeImageView;
@property (nonatomic, retain) UIView *theatreModeBackgroundView;

@end

@implementation DFPhotoDetailViewController

@synthesize actionAdapter = _actionAdapter;
@synthesize userLikeActionID = _userLikeActionID;


- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject
{
  self = [super init];
  if (self) {
    _openKeyboardOnAppear = NO;
    _photoObject = photoObject;
    _templateCell = [DFCommentTableViewCell templateCell];
    _userLikeActionID = [[[self.photoObject userFavoriteAction] id] longLongValue];
    [self observeNotifications];
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

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(newDataArrived)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)reloadData
{
  self.unreadActions = [[DFPeanutNotificationsManager sharedManager] unreadNotifications];
  _photoObject = [[DFPeanutFeedDataManager sharedManager] photoWithID:self.photoObject.id shareInstance:self.photoObject.share_instance.longLongValue];
  
  // Need to reload this because its a singlton
  _comments = [[self.photoObject actionsOfType:DFPeanutActionComment forUser:0] mutableCopy];
  
  [self reloadProfileWithContextData];
  
  if ([_comments count] > 0) {
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  } else {
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  }
  
  [self.tableView reloadData];
}

- (void)newDataArrived
{
  [self reloadData];
  
  // Temporarily disable marking actions as seen until can be reworked.
  // Issue is that the server doesn't know that the action is read so the badge on the homescreen is different from the app
  //[self markActionsAsSeen];
}


- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
  [self configureProfileWithContext];
  [self configureCommentToolbar];
  [self reloadData];
  [self textDidChange:self.commentToolbar.textField];
  [self configureTouchTableViewGesture];
}

- (void)markActionsAsSeen
{
  // mark the action IDs for the photo object seen
  NSMutableArray *actionIDs = [NSMutableArray new];
  for (DFPeanutAction *action in self.photoObject.actions) {
    if (action.id) [actionIDs addObject:action.id];
    else DDLogWarn(@"%@ action with no ID, can't mark as seen: %@", self.class, action);
  }
  [[DFPeanutNotificationsManager sharedManager] markActionIDsSeen:actionIDs];
  
  if (!self.photoObject.evaluated.boolValue) {
    [[DFPeanutFeedDataManager sharedManager] setHasEvaluatedPhoto:self.photoObject.id shareInstance:[self.photoObject.share_instance longLongValue]];
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  if (self.openKeyboardOnAppear) {
    [self scrollToLast];
    [self.commentToolbar.textField becomeFirstResponder];
  }

  [DFAnalytics
   logViewController:self
   appearedWithParameters:
   @{
     @"numComments" : [DFAnalytics bucketStringForObjectCount:self.comments.count],
     @"unreadLikes" : [DFAnalytics bucketStringForObjectCount:[[self.photoObject unreadActionsOfType:DFPeanutActionFavorite] count]],
     @"unreadComments" : [DFAnalytics bucketStringForObjectCount:[[self.photoObject unreadActionsOfType:DFPeanutActionComment] count]],
     }];
  
  [self markActionsAsSeen];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [self.commentToolbar.textField resignFirstResponder];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - View Configuration

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  [tableView registerNib:[UINib nibForClass:[DFCommentTableViewCell class]]
  forCellReuseIdentifier:@"cell"];
  [tableView registerNib:[UINib nibForClass:[DFButtonTableViewCell class]]
  forCellReuseIdentifier:@"buttonCell"];
  [tableView registerNib:[UINib nibForClass:[DFNoResultsTableViewCell class]]
  forCellReuseIdentifier:@"noResults"];
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.commentToolbar.frame.size.height * 2.0, 0);
  self.tableView.separatorInset = [DFCommentTableViewCell edgeInsets];
}

- (void)configureTouchTableViewGesture
{
  UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(tapRecognizerChanged:)];
  tapGestureRecognizer.cancelsTouchesInView = NO;
  [self.tableView addGestureRecognizer:tapGestureRecognizer];
  
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)configureProfileWithContext
{
  for (DFProfileStackView *psv in @[self.senderProfileStackView, self.recipientsProfileStackView]) {
    psv.backgroundColor = [UIColor clearColor];
    psv.showNames = YES;
    psv.delegate = self;
  }
  
  self.recipientsProfileStackView.photoMargins = 5;
}

- (void)reloadProfileWithContextData
{
  if (self.nuxStep) {
    self.senderProfileStackView.maxAbbreviationLength = 2;
    [self.senderProfileStackView setPeanutUser:[DFPeanutUserObject TeamSwapUser]];
    
    [self.recipientsProfileStackView setPeanutUser:[[DFUser currentUser] peanutUser]];
    return;
  }
  
  DFPeanutUserObject *sender = [[DFPeanutFeedDataManager sharedManager]
                                userWithID:self.photoObject.user];
  
  [self.senderProfileStackView setPeanutUser:sender];
  DFPeanutAction *senderLikeAction = [[self.photoObject actionsOfType:DFPeanutActionFavorite
                                                              forUser:sender.id] firstObject];
  if (senderLikeAction && [self.unreadActions containsObject:senderLikeAction]) {
    [self.senderProfileStackView
     setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeUnreadProfileBadge"]
     forUser:sender];
  } else if (senderLikeAction) {
    [self.senderProfileStackView
     setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeOnProfileBadge"]
     forUser:sender];
  }
  
  
  NSArray *recipientIDs = [self.photoObject.actor_ids arrayByRemovingObject:@(sender.id)];
  NSArray *recipientUsers = [recipientIDs arrayByMappingObjectsWithBlock:^id(NSNumber *userID) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:userID.longLongValue];
    if (!user) {
      DDLogError(@"%@ got nill user for userID:%@", self.class, userID);
      user = [[DFPeanutUserObject alloc] init];
    }
    return user;
  }];
  [self.recipientsProfileStackView setPeanutUsers:recipientUsers];
  for (DFPeanutUserObject *recipient in recipientUsers) {
    // if the recipient has no UID they can't have taken an action
    // and the actionsOfType:forUser uses UID 0 as an "any" val, so we should skip UID 0 recipients
    if (recipient.id == 0) continue;
    DFPeanutAction *likeAction = [[self.photoObject actionsOfType:DFPeanutActionFavorite forUser:recipient.id] firstObject];
    if (likeAction) {
      if ([self.unreadActions containsObject:likeAction]) {
        [self.recipientsProfileStackView setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeUnreadProfileBadge"]
                                               forUser:recipient];
      } else {
        [self.recipientsProfileStackView setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeOnProfileBadge"]
                                               forUser:recipient];
      }
    } else {
      [self.recipientsProfileStackView setBadgeImage:nil
                                             forUser:recipient];
    }
  }
}

- (void)configureCommentToolbar
{
  if (self.nuxStep) [self.commentToolbar removeFromSuperview];
  DFPhotoDetailViewController __weak *weakSelf = self;
  
  self.commentToolbar.tintColor = [UIColor whiteColor];
  self.commentToolbar.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];

  //configure like
  [self.commentToolbar setLikeBarButtonItemOn:(self.userLikeActionID > 0)];
  self.commentToolbar.likeHandler = ^{
    [weakSelf likeItemPressed:weakSelf.commentToolbar.likeButton];
  };
  
  // configure commenting
  [self.commentToolbar.textField addTarget:self
                     action:@selector(editingStartedOrStopped:)
           forControlEvents:UIControlEventEditingDidBegin | UIControlEventEditingDidEnd];
  self.commentToolbar.sendBlock = ^(NSString *text) {
    [weakSelf sendComment:text];
  };
  
  // configure more button
  self.commentToolbar.moreHandler = ^{
    [weakSelf showMoreActions];
  };
  
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.commentToolbar.frame.size.height, 0);
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self configurePhotoView];
  [self configureTheatreModeView];
  [self configureTemplateCell];
}

- (void)configureTemplateCell
{
  CGRect frame = self.templateCell.frame;
  frame.size.width = self.view.frame.size.width;
  self.templateCell.frame = frame;
  [self.templateCell setNeedsLayout];
}

- (CGRect)photoTableHeaderFrame
{
  CGFloat aspectRatio;
  if (self.photoObject.full_height && self.photoObject.full_width) {
    aspectRatio = self.photoObject.full_height.floatValue / self.photoObject.full_width.floatValue;
  } else {
    aspectRatio = 1.0;
  }
  CGRect frame = CGRectMake(10,
                            0,
                            self.view.frame.size.width - 20,
                            (self.view.frame.size.width - 20) * aspectRatio);
  return frame;
}

- (void)configurePhotoView
{
  CGRect frame = [self photoTableHeaderFrame];
  if (!self.imageView) {
    self.imageView = [[DFRemoteImageView alloc] initWithFrame:frame];
    self.imageView.clipsToBounds = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  } else {
    self.imageView.frame = frame;
  }
  
  if (self.nuxStep) {
    self.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
    [self.imageView loadImageWithID:self.photoObject.id
                       deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic];
  }
  [self.tableView setTableHeaderView:self.imageView];
  
  // photo view actions
  [self addGestureRecognizersToImageView:self.imageView];
}

- (void)configureTheatreModeView
{
  if (!self.theatreModeImageView) {
    // background
    self.theatreModeBackgroundView = [UIView new];
    self.theatreModeBackgroundView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.theatreModeBackgroundView];
    [self.theatreModeBackgroundView constrainToSuperviewSize];
    self.theatreModeBackgroundView.hidden = !_theatreModeEnabled;
    
    // image view
    self.theatreModeImageView = [[DFRemoteImageView alloc] initWithFrame:self.view.frame];
    self.theatreModeImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.theatreModeImageView];
    [self.theatreModeImageView constrainToSuperviewSize];
    [self addGestureRecognizersToImageView:self.theatreModeImageView];
    self.theatreModeImageView.userInteractionEnabled = YES;
    self.theatreModeImageView.hidden = !_theatreModeEnabled;
    
    // we need to call layoutSubviews here or the system gets cranky on iOS7
    // because another layout pass is required and this is called from viewDidLayoutSubviews
    [self.view layoutSubviews];
  }
  [self.theatreModeImageView loadImageWithID:self.photoObject.id
                                deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic];
}

- (void)addGestureRecognizersToImageView:(UIImageView *)imageView
{
  UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(photoSingleTapped:)];
  singleTapRecognizer.numberOfTapsRequired = 1;
  [imageView addGestureRecognizer:singleTapRecognizer];

  UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(photoDoubleTapped:)];
  doubleTapRecognizer.numberOfTapsRequired = 2;
  [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
  [imageView addGestureRecognizer:doubleTapRecognizer];
  
  
  UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                                       initWithTarget:self
                                                       action:@selector(photoLongPressed:)];
  [imageView addGestureRecognizer:longPressRecognizer];
}

#pragma mark - UITableView Delegate/Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  if (self.nuxStep) return 0;
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self comments] count];
}

- (NSArray *)comments
{
  if (!_comments) {
    _comments = [[self.photoObject actionsOfType:DFPeanutActionComment forUser:0] mutableCopy];
  }
  return _comments;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFCommentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  
  if ([[self comments] count] == 0) {
    DFNoResultsTableViewCell *noResults = [self.tableView dequeueReusableCellWithIdentifier:@"noResults"];
    noResults.label.text = @"No Comments Yet";
    return noResults;
  }
  
  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  [cell.profilePhotoStackView setPeanutUser:[[DFPeanutFeedDataManager sharedManager] userWithID:comment.user]];
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:comment.user];
  cell.nameLabel.text = [user fullName];
  cell.commentLabel.text = comment.text;
  cell.timestampLabel.text = [NSDateFormatter relativeTimeStringSinceDate:comment.time_stamp
                                                               abbreviate:YES];
  
  
  [self setCommentCell:cell
             deletable:(comment.user == [[DFUser currentUser] userID])
               comment:comment indexPath:indexPath];
  
  if ([self.unreadActions containsObject:comment]) {
    cell.backgroundColor = [DFStrandConstants unreadNotificationBackgroundColor];
  } else {
    cell.backgroundColor = [UIColor clearColor];
  }
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

- (void)setCommentCell:(DFCommentTableViewCell *)cell
             deletable:(BOOL)isDeletable
               comment:(DFPeanutAction *)comment
             indexPath:(NSIndexPath *)indexPath
{
  if (![cell.class isSubclassOfClass:[DFCommentTableViewCell class]]) return;
  

    cell.gestureRecognizers = @[];
  if (isDeletable) {
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                                         initWithTarget:self
                                                         action:@selector(promptToDeleteComment:)];
    [cell addGestureRecognizer:longPressRecognizer];
  }
}

#pragma mark - Actions

- (void)promptToDeleteComment:(UIGestureRecognizer *)sender
{
  if (sender.state != UIGestureRecognizerStateBegan) return;
  [self.commentToolbar.textField resignFirstResponder];
  
  NSIndexPath *commentIndexPath = [self.tableView indexPathForCell:(UITableViewCell *)sender.view];
  DFPeanutAction *comment = self.comments[commentIndexPath.row];
  
  self.alertController = [DFAlertController alertControllerWithTitle:@"Delete this comment?"
                                                             message:nil
                                                      preferredStyle:DFAlertControllerStyleActionSheet];
  [self.alertController addAction:[DFAlertAction
                                   actionWithTitle:@"Delete"
                                   style:DFAlertActionStyleDestructive
                                   handler:^(DFAlertAction *action) {
                                     [self deleteComment:comment];
                                   }]];
  [self.alertController addAction:[DFAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:DFAlertActionStyleCancel
                                   handler:^(DFAlertAction *action) {
                                     
                                   }]];
  [self.alertController showWithParentViewController:self animated:YES completion:nil];
}

- (IBAction)likeItemPressed:(id)sender {
  BOOL newLikeValue = (self.userLikeActionID == 0);
  DFActionID oldID = self.userLikeActionID;
  self.userLikeActionID = newLikeValue;
  if (newLikeValue) {
    DFPeanutAction *fakeAction = [[DFPeanutAction alloc] init];
    fakeAction.action_type = DFPeanutActionFavorite;
    fakeAction.user = [[DFUser currentUser] userID];
    self.photoObject.actions = [self.photoObject.actions arrayByAddingObject:fakeAction];
  } else {
    DFPeanutAction *oldAction = [[self.photoObject actionsOfType:DFPeanutActionFavorite
                                                        forUser:[[DFUser currentUser] userID]] firstObject];
    if (oldAction)
      self.photoObject.actions = [self.photoObject.actions arrayByRemovingObject:oldAction];
  }
  [self reloadProfileWithContextData];
  [[DFPeanutFeedDataManager sharedManager]
   setLikedByUser:newLikeValue
   photo:self.photoObject.id
   shareInstance:self.photoObject.share_instance.longLongValue
   oldActionID:oldID
   success:^(DFActionID actionID) {
     self.userLikeActionID = actionID;
     [self.class logController:self actionType:DFPeanutActionFavorite result:DFAnalyticsValueResultSuccess];
     if (newLikeValue) {
       [SVProgressHUD showImage:[UIImage imageNamed:@"Assets/Icons/LikeOnToolbarIcon"] status:@"Liked"];
     } else {
       [SVProgressHUD showImage:[UIImage imageNamed:@"Assets/Icons/LikeOffToolbarIcon"] status:@"Unliked"];
     }
     
   } failure:^(NSError *error) {
     [self.class logController:self actionType:DFPeanutActionFavorite result:DFAnalyticsValueResultFailure];
   }];
}

- (IBAction)addPersonPressed:(id)sender {
  NSArray *peanutContacts = self.photoObject.actorPeanutContacts;
  DFInviteStrandViewController *inviteStrandController = [[DFInviteStrandViewController alloc]
                                                          initWithSuggestedPeanutContacts:nil
                                                          notSelectablePeanutContacts:peanutContacts
                                                          notSelectableReason:@"Already Member"];
  inviteStrandController.photoObject = self.photoObject;
  [DFNavigationController presentWithRootController:inviteStrandController
                                           inParent:self
                                withBackButtonTitle:@"Cancel"];
}

- (void)setUserLikeActionID:(DFActionID)userLikeActionID
{
  _userLikeActionID = userLikeActionID;
  [self configureCommentToolbar];
}

- (void)deleteComment:(DFPeanutAction *)comment
{
  NSUInteger commentIndex = [self.comments indexOfObject:comment];
  if (commentIndex == NSNotFound) {
    [SVProgressHUD showErrorWithStatus:@"Could not delete"];
    return;
  }
  NSIndexPath *indexPath = [NSIndexPath indexPathForRow:commentIndex inSection:0];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView beginUpdates];
    [self.comments removeObject:comment];
    if (self.comments.count > 0) {
      [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                            withRowAnimation:UITableViewRowAnimationFade];
    } else {
      [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];
  });
  
  [self.actionAdapter removeAction:comment success:^(NSArray *resultObjects) {
    DDLogInfo(@"%@ successfully removed action: %@", self.class, comment);
    [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFInboxFeed completion:nil];
  } failure:^(NSError *error) {
    DDLogError(@"%@ failed to remove action: %@", self.class, error);
    [SVProgressHUD showErrorWithStatus:@"Failed to delete comment"];
  }];
}

- (IBAction)sendComment:(NSString *)comment {
  if (self.commentToolbar.textField.text.length == 0) return;
  
  DFPeanutAction *action = [[DFPeanutAction alloc] init];
  action.user = [[DFUser currentUser] userID];
  action.action_type = DFPeanutActionComment;
  action.text = comment;
  action.photo = @(self.photoObject.id);
  action.share_instance = @(self.photoObject.share_instance.longLongValue);
  action.time_stamp = [NSDate date];
  
  [self addComment:action];
  self.commentToolbar.textField.text = @"";
  [self.commentToolbar textChanged:self.commentToolbar.textField];
  DFPhotoDetailViewController __weak *weakSelf = self;
  [self.actionAdapter addAction:action success:^(NSArray *resultObjects) {
    DDLogInfo(@"%@ adding comment succeeded:%@", weakSelf.class, resultObjects);
    DFPeanutAction *newComment = [resultObjects firstObject];
    NSUInteger commentWithNoIDIndex = [weakSelf.comments indexOfObject:action];
    if (commentWithNoIDIndex != NSNotFound) {
      // need to check fo NSNotFound as a refresh from server may have already replaced it
      [weakSelf.comments replaceObjectAtIndex:commentWithNoIDIndex withObject:newComment];
      // replace the delete action on the cell
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:commentWithNoIDIndex inSection:0];
      DFCommentTableViewCell *cell = (DFCommentTableViewCell *)[weakSelf.tableView cellForRowAtIndexPath:indexPath];
      if (cell && [cell.class isSubclassOfClass:[DFCommentTableViewCell class]]) {
        // if comments are not expanded, we might not have a comment cell showing for it
        [weakSelf setCommentCell:cell deletable:YES comment:action indexPath:indexPath];
      }
    }
    [weakSelf.class logController:weakSelf actionType:DFPeanutActionComment result:DFAnalyticsValueResultSuccess];
  } failure:^(NSError *error) {
    DDLogError(@"%@ adding comment error:%@", weakSelf.class, error);
    [weakSelf showCommentError:action];
    [weakSelf.class logController:weakSelf actionType:DFPeanutActionComment result:DFAnalyticsValueResultFailure];
  }];
}

- (void)showMoreActions
{
  DFPhotoDetailViewController __weak *weakSelf = self;
  self.alertController = [DFAlertController alertControllerWithTitle:nil
                                                             message:nil
                                                      preferredStyle:DFAlertControllerStyleActionSheet];
  if (self.photoObject.user == [[DFUser currentUser] userID]) {
    [self.alertController addAction:[DFAlertAction
                                     actionWithTitle:@"Delete"
                                     style:DFAlertActionStyleDestructive
                                     handler:^(DFAlertAction *action) {
                                       [weakSelf deletePhoto];
                                     }]];
  }
  [self.alertController addAction:[DFAlertAction
                                   actionWithTitle:@"Save"
                                   style:DFAlertActionStyleDefault
                                   handler:^(DFAlertAction *action) {
                                     [weakSelf savePhotoToCameraRoll];
                                   }]];
  
  [self.alertController addAction:[DFAlertAction
                                   actionWithTitle:@"Share"
                                   style:DFAlertActionStyleDefault
                                   handler:^(DFAlertAction *action) {
                                     [weakSelf sharePhoto];
                                   }]];
    [self.alertController addAction:[DFAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:DFAlertActionStyleCancel
                                   handler:^(DFAlertAction *action) {}]];
  
  [self.alertController showWithParentViewController:self
                              overridePresentingView:self.imageView
                                            animated:YES
                                          completion:nil];
}

- (void)deletePhoto
{
  DFPhotoDetailViewController __weak *weakSelf = self;
  DFAlertController *confirmController = [DFAlertController
                                          alertControllerWithTitle:@"Delete Photo?"
                                          message:@"Other strand users will no longer be able to see this photo."
                                          preferredStyle:DFAlertControllerStyleAlert];
  [confirmController addAction:[DFAlertAction
                                actionWithTitle:@"Delete"
                                style:DFAlertActionStyleDestructive
                                handler:^(DFAlertAction *action) {
                                  [[DFPeanutFeedDataManager sharedManager]
                                   deleteShareInstance:self.photoObject.share_instance.longLongValue
                                   success:^{
                                     [SVProgressHUD showSuccessWithStatus:@"Deleted"];
                                     [weakSelf dismissViewControllerAnimated:YES completion:nil];
                                   } failure:^(NSError *error) {
                                     [SVProgressHUD
                                      showErrorWithStatus:[NSString stringWithFormat:@"Failed: %@",
                                      error.localizedDescription]];
                                   }];
                                  
                                }]];
  [confirmController addAction:[DFAlertAction
                                actionWithTitle:@"Cancel"
                                style:DFAlertActionStyleCancel
                                handler:^(DFAlertAction *action) {}]];
  [confirmController showWithParentViewController:self animated:YES completion:nil];
  
}

- (void)savePhotoToCameraRoll
{
  DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithFeedObject:self.photoObject];
  [[DFPhotoStore sharedStore] saveImageToCameraRoll:self.imageView.image
                                       withMetadata:peanutPhoto.metadataDictionary
                                         completion:^(NSURL *assetURL, NSError *error) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                             if (error) {
                                               [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                                             } else {
                                               [SVProgressHUD showSuccessWithStatus:@"Saved"];
                                             }
                                           });
                                         }];
}

- (void)sharePhoto
{
  UIActivityViewController *avc = [[UIActivityViewController alloc]
                                   initWithActivityItems:@[self.imageView.image]
                                   applicationActivities:nil];
  avc.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
  [self presentViewController:avc animated:YES completion:nil];
}

+ (void)logController:(DFPhotoDetailViewController *)controller actionType:(DFPeanutActionType)actionType result:(NSString *)result
{
  [DFAnalytics logPhotoActionTaken:actionType
                fromViewController:controller
                            result:result
                       photoObject:controller.photoObject];
}


- (void)addComment:(DFPeanutAction *)action
{
  [self.tableView beginUpdates];
  [self.tableView
   insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.comments.count inSection:0]]
   withRowAnimation:UITableViewRowAnimationFade];
  [self.comments addObject:action];
  [self.tableView endUpdates];
  
  
  [self scrollToLast];
}

- (void)showCommentError:(DFPeanutAction *)action
{
  [SVProgressHUD showErrorWithStatus:@"Posting comment failed."];
}

- (IBAction)textDidChange:(UITextField *)sender {
  if (sender.text.length > 0) {
    self.commentToolbar.sendButton.enabled = YES;
  } else {
    self.commentToolbar.sendButton.enabled = NO;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

}

- (void)scrollToLast
{
  if (self.comments.count > 0) {
    DFPhotoDetailViewController __weak *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf.tableView
       scrollToRowAtIndexPath:[NSIndexPath
                               indexPathForRow:weakSelf.comments.count-1 inSection:0]
       atScrollPosition:UITableViewScrollPositionTop
       animated:YES];
    });
  }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return 69.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if ([[self comments] count] == 0) {
    return [DFNoResultsTableViewCell desiredHeight];
  }

  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  if (![self.templateCell.commentLabel.text isEqualToString:comment.text]) {
    self.templateCell.commentLabel.text = comment.text;
    [self.templateCell setNeedsLayout];
  }
  return self.templateCell.rowHeight;
}

- (void)profileStackView:(DFProfileStackView *)profileStackView peanutUserTapped:(DFPeanutUserObject *)peanutUser
{
  if (peanutUser.id != [[DFUser currentUser] userID]) {
    DFFriendProfileViewController *friendViewController = [[DFFriendProfileViewController alloc] initWithPeanutUser:peanutUser];
    [DFNavigationController presentWithRootController:friendViewController inParent:self];
  }
}

#pragma mark - Photo view gesture recognizers

- (void)photoSingleTapped:(UIGestureRecognizer *)sender
{
  [self toggleTheatreMode];
}

- (void)photoDoubleTapped:(UIGestureRecognizer *)sender
{
  if (sender.state == UIGestureRecognizerStateEnded)
    [self likeItemPressed:sender];
}

- (void)photoLongPressed:(UIGestureRecognizer *)sender
{
  if (sender.state == UIGestureRecognizerStateBegan)
    [self showMoreActions];
}

#pragma mark - State changes


- (void)editingStartedOrStopped:(UITextField *)sender
{
  if (sender.isFirstResponder)
    [self scrollToLast];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  [self.commentToolbar.textField resignFirstResponder];
}

- (void)tapRecognizerChanged:(UITapGestureRecognizer *)tapRecognizer
{
  [self.commentToolbar.textField resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
}

- (void)updateFrameFromKeyboardNotif:(NSNotification *)notification
{
  if (self.disableKeyboardHandler) return;
  //CGRect keyboardStartFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
  CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGFloat keyboardEndBottomDistance = self.view.frame.size.height - CGRectGetMinY(keyboardEndFrame);

  self.contentBottomConstraint.constant = keyboardEndBottomDistance;
  [self.view setNeedsUpdateConstraints];
  
  NSNumber *duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
  NSNumber *animatinoCurve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
  
  [self.view setNeedsLayout];
  [UIView
   animateWithDuration:duration.floatValue
   delay:0.0
   options:animatinoCurve.integerValue
   animations:^{
     [self.view layoutIfNeeded];
   } completion:^(BOOL finished) {
     
   }];
}

#pragma mark - Theatre mode

- (void)toggleTheatreMode
{
  self.theatreModeEnabled = !self.theatreModeEnabled;
}

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled
{
  _theatreModeEnabled = theatreModeEnabled;
  if (theatreModeEnabled && self.theatreModeImageView) {
    self.theatreModeBackgroundView.hidden = NO;
    self.theatreModeImageView.hidden = NO;
  } else if (self.theatreModeImageView){
    self.theatreModeImageView.hidden = YES;
    self.theatreModeBackgroundView.hidden = YES;
  }
}

#pragma mark - Adapters

- (DFPeanutActionAdapter *)actionAdapter
{
  if (!_actionAdapter) _actionAdapter = [[DFPeanutActionAdapter alloc] init];
  return _actionAdapter;
}

@end
