//
//  DFNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFNUXViewController.h"

NSString *const DFPhoneNumberNUXUserInfoKey = @"phone";
NSString *const DFDisplayNameNUXUserInfoKey = @"display_name";


@interface DFNUXViewController ()

@end

@implementation DFNUXViewController

- (void)completedWithUserInfo:(NSDictionary *)userInfo
{
  [self.delegate NUXController:self
   completedWithUserInfo:userInfo];
}


@end
