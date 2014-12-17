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
#import "DFPeanutFeedDataManager.h"

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
    [self observeNotifs];
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
  
  [self configurePhotoDetailView];
  [self configureSwipableButtonView];
}


- (void)observeNotifs
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)configurePhotoDetailView
{
  DFPhotoDetailViewController *pdvc;
  if (self.nuxStep) {
    pdvc = [[DFPhotoDetailViewController alloc] initWithNuxStep:self.nuxStep];
  } else {
    DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager] photoWithID:self.photoID
                                                                                  inStrand:self.strandID];
    DFPeanutFeedObject *postsObject = [[DFPeanutFeedDataManager sharedManager] strandPostsObjectWithId:self.strandID];
    pdvc = [[DFPhotoDetailViewController alloc]
                                      initWithPhotoObject:photoObject
                                      inPostsObject:postsObject];
  }
  self.photoDetailViewController = pdvc;
  self.photoDetailViewController.compressedModeEnabled = YES;
  self.photoDetailViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
  self.photoDetailViewController.disableKeyboardHandler = YES;
}

- (void)configureSwipableButtonView
{
  self.swipableButtonView.delegate = self;
  [self.swipableButtonView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingSkipButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.otherButton removeFromSuperview];
  [self.swipableButtonView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingLikeButtonIcon"]
   forState:UIControlStateNormal];
  for (UIButton *button in @[self.swipableButtonView.noButton,
                             self.swipableButtonView.yesButton]) {
    [button setTitle:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor]; 
  }
  
  [self.swipableButtonView configureToUseView:self.photoDetailViewController.view];
}

- (void)viewDidLayoutSubviews
{
  if (self.nuxStep) {
    self.swipableButtonView.imageView.image = [UIImage imageNamed:@"Assets/Nux/NuxReceiveImage"];
  } else {
    [[DFImageManager sharedManager]
     imageForID:self.photoID
     pointSize:self.swipableButtonView.centerView.frame.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         self.swipableButtonView.imageView.image = image;
       });
     }];
  }
}

- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
                 buttonSelected:(UIButton *)button
{
  if (button == self.swipableButtonView.noButton) {
    if (self.nextHandler) self.nextHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonView.otherButton) {
    if (self.commentHandler) self.commentHandler(self.photoID, self.strandID);
  } else if (button == self.swipableButtonView.yesButton) {
    if (self.likeHandler) self.likeHandler(self.photoID, self.strandID);
  }
}

- (void)keyboardWillShow:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
  [self.swipableButtonView setButtonsHidden:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  [self updateFrameFromKeyboardNotif:notification];
  [self.swipableButtonView setButtonsHidden:NO];
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

@end
