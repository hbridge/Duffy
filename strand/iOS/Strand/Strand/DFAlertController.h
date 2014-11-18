//
//  DFAlertController.h
//  Strand
//
//  Created by Henry Bridge on 11/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFAlertAction.h"

@interface DFAlertController : NSObject <UIAlertViewDelegate, UIActionSheetDelegate>

typedef NS_ENUM(NSInteger, DFAlertControllerStyle) {
  DFAlertControllerStyleActionSheet  = 0,
  DFAlertControllerStyleAlert
};

@property (nonatomic, retain) NSArray *actions;

+ (DFAlertController *)alertControllerWithTitle:(NSString *)title
                                        message:(NSString *)message
                                 preferredStyle:(DFAlertControllerStyle)preferredStyle;

- (void)addAction:(DFAlertAction *)alertAction;
- (void)showWithParentViewController:(UIViewController *)parentViewController
                            animated:(BOOL)animated
                          completion:(DFVoidBlock)completion;

@end
