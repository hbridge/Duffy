//
//  DFAlertAction.m
//  Strand
//
//  Created by Henry Bridge on 11/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAlertAction.h"

@implementation DFAlertAction

+ (DFAlertAction *)actionWithTitle:(NSString *)title
                             style:(DFAlertActionStyle)style
                           handler:(void (^)(DFAlertAction *action))handler
{
  DFAlertAction *action = [[DFAlertAction alloc] init];
  action.title = title;
  action.style = style;
  action.handler = handler;
  return action;
}


- (UIAlertActionStyle)uiAlertActionStyle
{
  if (self.style == DFAlertActionStyleDestructive) {
    return UIAlertActionStyleDestructive;
  } else if (self.style == DFAlertActionStyleCancel) {
    return UIAlertActionStyleCancel;
  }
  
  return UIAlertActionStyleDefault;
}

@end
