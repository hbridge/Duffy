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

@interface DFCommentViewController ()

@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (nonatomic, retain) NSMutableArray *comments;
@property (nonatomic, retain) DFCommentTableViewCell *templateCell;

@end

@implementation DFCommentViewController

@synthesize actionAdapter = _actionAdapter;

- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject
                      inPostsObject:(DFPeanutFeedObject *)postsObject
{
  self = [super init];
  if (self) {
    _photoObject = photoObject;
    _postsObject = postsObject;
    _templateCell = [DFCommentTableViewCell templateCell];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  UIBarButtonItem *textBarButton = [self.toolbar.items firstObject];
  UIBarButtonItem *sendBarButton = [self.toolbar.items objectAtIndex:1];
  textBarButton.width = self.toolbar.frame.size.width - sendBarButton.width - 36;
  
}

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  [tableView registerNib:[UINib nibForClass:[DFCommentTableViewCell class]]
  forCellReuseIdentifier:@"cell"];
  self.tableView.contentInset = UIEdgeInsetsMake(0, 0, self.toolbar.frame.size.height * 2.0, 0);
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
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
  
  DFPeanutAction *comment = [[self comments] objectAtIndex:indexPath.row];
  [cell.profilePhotoStackView setNames:@[comment.user_display_name]];
  cell.nameLabel.text = comment.user_display_name;
  cell.commentLabel.text = comment.text;
  cell.timestampLabel.text = [NSDateFormatter relativeTimeStringSinceDate:[NSDate date] abbreviate:YES];
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return 69.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
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
  action.user_display_name = [[DFUser currentUser] displayName];
  
  [self addComment:action];
  DFCommentViewController __weak *weakSelf = self;
  [self.actionAdapter addAction:action success:^(NSArray *resultObjects) {
    DDLogInfo(@"%@ adding comment succeeded:%@", [DFCommentViewController class], resultObjects);
  } failure:^(NSError *error) {
    DDLogError(@"%@ adding comment error:%@", [DFCommentViewController class], error);
    [weakSelf showCommentError:action];
  }];
}


- (void)addComment:(DFPeanutAction *)action
{
  [self.tableView beginUpdates];
  
  [self.tableView
   insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.comments.count inSection:0]]
   withRowAnimation:UITableViewRowAnimationFade];
  [self.comments addObject:action];
  [self.tableView endUpdates];
  
  DFCommentViewController __weak *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf.tableView
     scrollToRowAtIndexPath:[NSIndexPath
                             indexPathForRow:weakSelf.comments.count-1 inSection:0]
     atScrollPosition:UITableViewScrollPositionTop
     animated:YES];
  });
}

- (void)showCommentError:(DFPeanutAction *)action
{
  
}

- (IBAction)textDidChange:(UITextField *)sender {
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
