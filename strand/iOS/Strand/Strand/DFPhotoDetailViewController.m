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

const NSUInteger CompressedModeMaxRows = 1;

@interface DFPhotoDetailViewController ()

@property (nonatomic) DFActionID userLikeActionID;
@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (nonatomic, retain) NSMutableArray *comments;
@property (nonatomic, retain) DFCommentTableViewCell *templateCell;
@property (nonatomic, retain) DFAlertController *alertController;
@property (nonatomic, retain) NSArray *unreadActions;

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
  [self.tableView reloadData];
}

- (void)newDataArrived
{
  [self reloadData];
  [self markActionsAsSeen];
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

  if (!self.compressedModeEnabled)
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
    psv.nameMode = DFProfileStackViewNameShowAlways;
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
     setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeUnreadButtonIcon"]
     forUser:sender];
  } else if (senderLikeAction) {
    [self.senderProfileStackView
     setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"]
     forUser:sender];
  }
  
  
  NSArray *recipientIDs = [self.photoObject.actor_ids arrayByRemovingObject:@(sender.id)];
  NSArray *recipientUsers = [recipientIDs arrayByMappingObjectsWithBlock:^id(NSNumber *userID) {
    return [[DFPeanutFeedDataManager sharedManager] userWithID:userID.longLongValue];
  }];
  [self.recipientsProfileStackView setPeanutUsers:recipientUsers];
  for (DFPeanutUserObject *recipient in recipientUsers) {
    // if the recipient has no UID they can't have taken an action
    // and the actionsOfType:forUser uses UID 0 as an "any" val, so we should skip UID 0 recipients
    if (recipient.id == 0) continue;
    DFPeanutAction *likeAction = [[self.photoObject actionsOfType:DFPeanutActionFavorite forUser:recipient.id] firstObject];
    if (likeAction) {
      if ([self.unreadActions containsObject:likeAction]) {
        [self.recipientsProfileStackView setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeUnreadButtonIcon"]
                                               forUser:recipient];
      } else {
        [self.recipientsProfileStackView setBadgeImage:[UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"]
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
  [self.commentToolbar.profileStackView setPeanutUser:[[DFUser currentUser] peanutUser]];
  [self setLikeBarButtonItemOn:(self.userLikeActionID > 0)];
  [self.commentToolbar.likeButton addTarget:self
                                     action:@selector(likeItemPressed:)
                           forControlEvents:UIControlEventTouchUpInside];
  [self.commentToolbar.textField addTarget:self
                     action:@selector(editingStartedOrStopped:)
           forControlEvents:UIControlEventEditingDidBegin | UIControlEventEditingDidEnd];
  self.commentToolbar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
  
  DFPhotoDetailViewController __weak *weakSelf = self;
  self.commentToolbar.sendBlock = ^(NSString *text) {
    [weakSelf sendComment:text];
  };
  
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

- (void)setCompressedModeEnabled:(BOOL)compressedModeEnabled
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _compressedModeEnabled = compressedModeEnabled;
    [self.view setNeedsLayout];
    if (self.compressedModeEnabled) self.commentToolbar.likeButtonDisabled = YES;
    [self.tableView reloadData];
  });
}

- (void)setCommentsExpanded:(BOOL)commentsExpanded
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _commentsExpanded = commentsExpanded;
    [self configureToolbarHidden];
    [self.tableView reloadData];
  });
}

- (void)configureToolbarHidden
{
  if (self.compressedModeEnabled && [self tableView:self.tableView numberOfRowsInSection:0] == 2 && !self.commentsExpanded) {
    self.commentToolbar.hidden = YES;
  } else {
    self.commentToolbar.hidden = NO;
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self configurePhotoView];
  [self configureTemplateCell];
 }

- (void)configureTemplateCell
{
  CGRect frame = self.templateCell.frame;
  frame.size.width = self.view.frame.size.width;
  self.templateCell.frame = frame;
  [self.templateCell setNeedsLayout];
}

- (void)configurePhotoView
{
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
    self.imageView = [[DFRemoteImageView alloc] initWithFrame:frame];
    self.imageView.clipsToBounds = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  } else {
    self.imageView.frame = frame;
  }
  
  if (self.compressedModeEnabled) {
    self.imageView.layer.cornerRadius = 4.0;
    self.imageView.layer.masksToBounds = YES;
  }

  if (self.compressedModeEnabled) {
    [self.addPersonButton removeFromSuperview];
  }
  self.tableView.separatorStyle = self.compressedModeEnabled ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
  [self configureToolbarHidden];
  
  if (self.nuxStep) {
    self.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
    [self.imageView loadImageWithID:self.photoObject.id
                       deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic];
  }
  [self.tableView setTableHeaderView:self.imageView];
}

#pragma mark - UITableView Delegate/Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  if (self.nuxStep) return 0;
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSUInteger numRows;
  if (self.compressedModeEnabled && !self.commentsExpanded) {
    numRows = MIN([[self comments] count], CompressedModeMaxRows + 1);
  } else {
    numRows = [[self comments] count];
  }
  return MAX(numRows, 1);
}

- (NSArray *)comments
{
  if (!_comments) {
    _comments = [[self.photoObject actionsOfType:DFPeanutActionComment forUser:0] mutableCopy];
  }
  return _comments;
}

- (BOOL)isShowMoreRow:(NSIndexPath *)indexPath
{
  return (self.compressedModeEnabled && indexPath.row == CompressedModeMaxRows && !self.commentsExpanded);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if  ([self isShowMoreRow:indexPath]) {
    DFButtonTableViewCell *buttonCell = [self.tableView dequeueReusableCellWithIdentifier:@"buttonCell"];
    NSString *title = [NSString stringWithFormat:@"Show %@ more comments",
                       @([[self comments] count] - CompressedModeMaxRows)];
    [buttonCell.button setTitle:title forState:UIControlStateNormal];
    return buttonCell;
  }
  DFCommentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  
  if ([[self comments] count] == 0) {
    DFNoResultsTableViewCell *noResults = [self.tableView dequeueReusableCellWithIdentifier:@"noResults"];
    noResults.noResultsLabel.text = @"No Comments Yet";
    return noResults;
  }
  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  [cell.profilePhotoStackView setPeanutUser:[[DFPeanutFeedDataManager sharedManager] userWithID:comment.user]];
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:comment.user];
  cell.nameLabel.text = [user fullName];
  cell.commentLabel.text = comment.text;
  cell.timestampLabel.text = [NSDateFormatter relativeTimeStringSinceDate:comment.time_stamp
                                                               abbreviate:YES];
  
  
  if (comment.user == [[DFUser currentUser] userID]) {
    [self addDeleteActionForCell:cell
                         comment:comment
                       indexPath:indexPath];
  }
  
  if ([self.unreadActions containsObject:comment]) {
    cell.backgroundColor = [DFStrandConstants unreadNotificationBackgroundColor];
  } else {
    cell.backgroundColor = [UIColor clearColor];
  }
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

- (void)addDeleteActionForCell:(DFCommentTableViewCell *)cell
                       comment:(DFPeanutAction *)comment
                     indexPath:(NSIndexPath *)indexPath
{
  if (![cell.class isSubclassOfClass:[DFCommentTableViewCell class]]) return;
  UILabel *hideLabel = [[UILabel alloc] init];
  hideLabel.text = @"Delete";
  hideLabel.textColor = [UIColor whiteColor];
  [hideLabel sizeToFit];
  [cell
   setSwipeGestureWithView:hideLabel
   color:[UIColor redColor]
   mode:MCSwipeTableViewCellModeExit
   state:MCSwipeTableViewCellState3
   completionBlock:^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
     [self.commentToolbar.textField resignFirstResponder];
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
                                        [cell swipeToOriginWithCompletion:nil];
                                      }]];
     [self.alertController showWithParentViewController:self animated:YES completion:nil];
   }];
  // the default color is the color that appears before you swipe far enough for the action
  // we set to the group tableview background color to blend in
  cell.defaultColor = [UIColor lightGrayColor];
}

#pragma mark - Actions

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
        [weakSelf addDeleteActionForCell:cell comment:newComment indexPath:indexPath];
      }
    }
    [weakSelf.class logController:weakSelf actionType:DFPeanutActionComment result:DFAnalyticsValueResultSuccess];
  } failure:^(NSError *error) {
    DDLogError(@"%@ adding comment error:%@", weakSelf.class, error);
    [weakSelf showCommentError:action];
    [weakSelf.class logController:weakSelf actionType:DFPeanutActionComment result:DFAnalyticsValueResultFailure];
  }];
}

+ (void)logController:(DFPhotoDetailViewController *)controller actionType:(DFPeanutActionType)actionType result:(NSString *)result
{
  [DFAnalytics logPhotoActionTaken:actionType
                fromViewController:controller.compressedModeEnabled ? controller.parentViewController : controller
                            result:result
                       photoObject:controller.photoObject];
}


- (void)addComment:(DFPeanutAction *)action
{
  [self.tableView beginUpdates];
  
  if (self.comments.count == 0)
  {
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationFade];
  }
  
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
  if ([self isShowMoreRow:indexPath]) {
    self.commentsExpanded = YES;
    [self.tableView reloadData];
  }
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
  } else if ([self isShowMoreRow:indexPath]) {
    return 44.0;
  }

  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  if (![self.templateCell.commentLabel.text isEqualToString:comment.text]) {
    self.templateCell.commentLabel.text = comment.text;
    [self.templateCell setNeedsLayout];
  }
  return self.templateCell.rowHeight;
}

#pragma mark - State changes


- (void)editingStartedOrStopped:(UITextField *)sender
{
  self.commentsExpanded = sender.isFirstResponder;
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

#pragma mark - Adapters

- (DFPeanutActionAdapter *)actionAdapter
{
  if (!_actionAdapter) _actionAdapter = [[DFPeanutActionAdapter alloc] init];
  return _actionAdapter;
}

@end
