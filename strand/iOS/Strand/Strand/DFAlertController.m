//
//  DFAlertController.m
//  Strand
//
//  Created by Henry Bridge on 11/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAlertController.h"

@interface DFAlertController ()

@property (nonatomic, retain) UIAlertController *uiAlertController;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *message;
@property (nonatomic) DFAlertControllerStyle style;

@end

static DFAlertController *CurrentAlertController = nil;

@implementation DFAlertController

+ (DFAlertController *)alertControllerWithTitle:(NSString *)title
                                        message:(NSString *)message
                                 preferredStyle:(DFAlertControllerStyle)preferredStyle
{
  CurrentAlertController = [[DFAlertController alloc] initWithTitle:title
                                                            message:message
                                                     preferredStyle:preferredStyle];
  return CurrentAlertController;
}


- (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
               preferredStyle:(DFAlertControllerStyle)preferredStyle
{
  self = [super init];
  if (self) {
    _title = title;
    _message = message;
    _style = preferredStyle;
    _actions = @[];
  }
  return self;
}

- (void)addAction:(DFAlertAction *)alertAction
{
  self.actions = [self.actions arrayByAddingObject:alertAction];
}


- (void)showWithParentViewController:(UIViewController *)parentViewController
                            animated:(BOOL)animated
                          completion:(DFVoidBlock)completion
{
  [self showWithParentViewController:parentViewController
              overridePresentingView:nil
                            animated:animated
                          completion:completion];
 }

- (void)showWithParentViewController:(UIViewController *)parentViewController
              overridePresentingView:(UIView *)view
                            animated:(BOOL)animated
                          completion:(DFVoidBlock)completion
{
  if ([UIAlertController class]) {
    UIAlertController *alertController = [self alertController];
    [parentViewController presentViewController:alertController
                                       animated:animated
                                     completion:completion];
  } else {
    if (self.style == DFAlertControllerStyleActionSheet) {
      UIActionSheet *actionSheet = [self actionSheet];
      UIView *presentingView = view ? view : parentViewController.view;
      [actionSheet showInView:presentingView];
    } else {
      UIAlertView *alertView = [self alertView];
      [alertView show];
    }
  }
}

- (UIAlertController *)alertController
{
  self.uiAlertController = [UIAlertController
                                          alertControllerWithTitle:self.title
                                          message:self.message
                                          preferredStyle:self.style == DFAlertControllerStyleActionSheet ?
                                            UIAlertControllerStyleActionSheet : UIAlertControllerStyleAlert];
  for (NSUInteger i = 0; i < self.actions.count; i++) {
    DFAlertAction *action = self.actions[i];
    UIAlertAction *uiAction = [UIAlertAction
                               actionWithTitle:action.title
                               style:action.uiAlertActionStyle
                               handler:^(UIAlertAction *completedAction) {
                                 NSUInteger actionIndex = [[self.uiAlertController actions]
                                                           indexOfObject:completedAction];
                                 DFAlertAction *action = self.actions[actionIndex];
                                 if (action.handler)
                                   action.handler(action);
                               }];
    [self.uiAlertController addAction:uiAction];
  }
  
  return self.uiAlertController;
}

- (UIActionSheet *)actionSheet
{
  UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
  actionSheet.delegate = self;
  actionSheet.title = self.title;
  for (NSUInteger i = 0; i < self.actions.count; i++) {
    DFAlertAction *action = self.actions[i];
    [actionSheet addButtonWithTitle:action.title];
    if (action.style == DFAlertActionStyleCancel) {
      actionSheet.cancelButtonIndex = i;
    } else if (action.style == DFAlertActionStyleDestructive) {
      actionSheet.destructiveButtonIndex = i;
    }
  }
  return actionSheet;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  DFAlertAction *action = self.actions[buttonIndex];
  action.handler(action);
}

- (UIAlertView *)alertView
{
  UIAlertView *alertView = [[UIAlertView alloc] init];
  alertView.title = self.title;
  alertView.message = self.message;
  alertView.delegate = self;
  for (NSUInteger i = 0; i < self.actions.count; i++) {
    DFAlertAction *action = self.actions[i];
    [alertView addButtonWithTitle:action.title];
    if (action.style == DFAlertActionStyleCancel) {
      alertView.cancelButtonIndex = i;
    }
  }
  return alertView;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  DFAlertAction *action = self.actions[buttonIndex];
  if (action.handler) action.handler(action);
}

- (NSArray *)titlesForActionsOfStyle:(DFAlertActionStyle)style
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFAlertAction *action in self.actions) {
    if (action.style == style) [result addObject:action];
  }
  return result;
}


@end
