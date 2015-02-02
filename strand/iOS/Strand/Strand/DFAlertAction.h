//
//  DFAlertAction.h
//  Strand
//
//  Created by Henry Bridge on 11/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFAlertAction : NSObject

typedef enum DFAlertActionStyle: NSInteger  {
  DFAlertActionStyleDefault  = 0,
  DFAlertActionStyleCancel ,
  DFAlertActionStyleDestructive
} DFAlertActionStyle;

@property (nonatomic, copy) NSString *title;
@property (nonatomic) DFAlertActionStyle style;
@property (nonatomic, copy) void (^handler)(DFAlertAction *action);

+ (DFAlertAction *)actionWithTitle:(NSString *)title
                             style:(DFAlertActionStyle)style
                           handler:(void (^)(DFAlertAction *action))handler;
- (UIAlertActionStyle)uiAlertActionStyle;

@end
