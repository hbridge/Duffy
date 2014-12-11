//
//  DFCommentViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentViewController.h"
#import "DFCommentTableViewCell.h"
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutActionAdapter.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFAnalytics.h"
#import "DFNoResultsTableViewCell.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFAlertController.h"

@interface DFCommentViewController ()

@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (nonatomic, retain) NSMutableArray *comments;
@property (nonatomic, retain) DFCommentTableViewCell *templateCell;
@property (nonatomic, retain) DFAlertController *alertController;

@end

@implementation DFCommentViewController

@synthesize actionAdapter = _actionAdapter;

- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject
                      inPostsObject:(DFPeanutFeedObject *)postsObject
{
  self = [super init];
  if (self) {
    _openKeyboardOnAppear = YES;
    _photoObject = photoObject;
    _postsObject = postsObject;
    _templateCell = [DFCommentTableViewCell templateCell];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
  [self textDidChange:self.textField];
  [self configureTouchTableViewGesture];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  self.textFieldItem.width = self.toolbar.frame.size.width - self.sendButton.width - 36;
}

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  [tableView registerNib:[UINib nibForClass:[DFCommentTableViewCell class]]
  forCellReuseIdentifier:@"cell"];
  [tableView registerNib:[UINib nibForClass:[DFNoResultsTableViewCell class]]
  forCellReuseIdentifier:@"noResults"];
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.toolbar.frame.size.height * 2.0, 0);
  self.tableView.separatorInset = [DFCommentTableViewCell edgeInsets];
}

- (void)configureTouchTableViewGesture
{
  UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(tapRecognizerChanged:)];
  [self.tableView addGestureRecognizer:tapGestureRecognizer];
  
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  DDLogVerbose(@"dragging");
  [self.textField resignFirstResponder];
}

- (void)tapRecognizerChanged:(UITapGestureRecognizer *)tapRecognizer
{
  DDLogVerbose(@"tableview tapped");
  [self.textField resignFirstResponder];
}


- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  if (self.openKeyboardOnAppear) {
    [self scrollToLast];
    [self.textField becomeFirstResponder];
  }
  [DFAnalytics logViewController:self
          appearedWithParameters:@{
                                   @"numComments" : [DFAnalytics bucketStringForObjectCount:self.comments.count]
                                   }];
}

- (void)scrollToLast
{
  if (self.comments.count > 0) {
    DFCommentViewController __weak *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf.tableView
       scrollToRowAtIndexPath:[NSIndexPath
                               indexPathForRow:weakSelf.comments.count-1 inSection:0]
       atScrollPosition:UITableViewScrollPositionTop
       animated:YES];
    });
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return MAX([[self comments] count], 1);
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
    noResults.noResultsLabel.text = @"No Comments Yet";
    return noResults;
  }
  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  [cell.profilePhotoStackView setPeanutUser:[self.postsObject actorWithID:comment.user]];
  cell.nameLabel.text = [comment fullNameOrYou];
  cell.commentLabel.text = comment.text;
  cell.timestampLabel.text = [NSDateFormatter relativeTimeStringSinceDate:comment.time_stamp
                                                               abbreviate:YES];
  
  
  if (comment.user == [[DFUser currentUser] userID]) {
    [self addDeleteActionForCell:cell
                         comment:comment
                       indexPath:indexPath];
  }
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

- (void)addDeleteActionForCell:(DFCommentTableViewCell *)cell
                       comment:(DFPeanutAction *)comment
                     indexPath:(NSIndexPath *)indexPath
{
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
     [self.textField resignFirstResponder];
     self.alertController = [DFAlertController alertControllerWithTitle:@"Delete this comment?"
                                                                              message:nil
                                                                       preferredStyle:DFAlertControllerStyleActionSheet];
     [self.alertController addAction:[DFAlertAction
                                 actionWithTitle:@"Delete"
                                 style:DFAlertActionStyleDestructive
                                 handler:^(DFAlertAction *action) {
                                   [self deleteCommentAtIndexPath:indexPath];
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
   
- (void)deleteCommentAtIndexPath:(NSIndexPath *)indexPath
   {
     DFPeanutAction *comment = self.comments[indexPath.row];
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
       [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:nil];
     } failure:^(NSError *error) {
       DDLogError(@"%@ failed to remove action: %@", self.class, error);
       [SVProgressHUD showErrorWithStatus:@"Failed to delete comment"];
     }];
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
  self.templateCell.commentLabel.text = comment.text;
  return self.templateCell.rowHeight;
}


#pragma mark - Actions


- (IBAction)sendButtonPressed:(id)sender {
  DFPeanutAction *action = [[DFPeanutAction alloc] init];
  action.user = [[DFUser currentUser] userID];
  action.action_type = DFPeanutActionComment;
  action.text = self.textField.text;
  action.photo = self.photoObject.id;
  action.strand = self.postsObject.id;
  action.time_stamp = [NSDate date];
  
  [self addComment:action];
  self.textField.text = @"";
  DFCommentViewController __weak *weakSelf = self;
  [self.actionAdapter addAction:action success:^(NSArray *resultObjects) {
    DDLogInfo(@"%@ adding comment succeeded:%@", [DFCommentViewController class], resultObjects);
    NSInteger commentWithNoIDIndex = [weakSelf.comments indexOfObject:action];
    [weakSelf.comments replaceObjectAtIndex:commentWithNoIDIndex withObject:[resultObjects firstObject]];
    [DFAnalytics logPhotoActionTaken:DFPeanutActionComment
                              result:DFAnalyticsValueResultSuccess
                         photoObject:weakSelf.photoObject
                         postsObject:weakSelf.postsObject];
  } failure:^(NSError *error) {
    DDLogError(@"%@ adding comment error:%@", [DFCommentViewController class], error);
    [weakSelf showCommentError:action];
    [DFAnalytics logPhotoActionTaken:DFPeanutActionComment
                              result:DFAnalyticsValueResultFailure
                         photoObject:weakSelf.photoObject
                         postsObject:weakSelf.postsObject];
  }];
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
    self.sendButton.enabled = YES;
  } else {
    self.sendButton.enabled = NO;
  }
}


- (void)keyboardWillShow:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
}

- (void)updateFrameFromKeyboardNotif:(NSNotification *)notification
{
  CGRect keyboardStartFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
  CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGFloat yDelta = keyboardStartFrame.origin.y - keyboardEndFrame.origin.y;
  CGRect frame = self.view.frame;
  frame.size.height -= yDelta;
  
  NSNumber *duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
  NSNumber *animatinoCurve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
  
  [UIView
   animateWithDuration:duration.floatValue
   delay:0.0
   options:animatinoCurve.integerValue
   animations:^{
     self.view.frame = frame;
   } completion:^(BOOL finished) {
     
  }];

}

- (DFPeanutActionAdapter *)actionAdapter
{
  if (!_actionAdapter) _actionAdapter = [[DFPeanutActionAdapter alloc] init];
  return _actionAdapter;
}

@end
