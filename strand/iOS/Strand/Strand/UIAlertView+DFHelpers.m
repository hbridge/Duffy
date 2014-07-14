//
//  UIAlertView+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UIAlertView+DFHelpers.h"

@implementation UIAlertView (DFHelpers)

+(void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)message
{
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                      message:message
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
  [alertView show];
}

@end
