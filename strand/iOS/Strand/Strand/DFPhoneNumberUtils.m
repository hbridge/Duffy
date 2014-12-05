//
//  DFPhoneNumberUtils.m
//  Strand
//
//  Created by Henry Bridge on 12/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhoneNumberUtils.h"

@implementation DFPhoneNumberUtils

+ (NSString *)normalizePhoneNumber:(NSString *)rawPhoneNumber
{
  // Get phone number into the format of +15551234567
  NSString *phoneNumber = [[rawPhoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
  if (![phoneNumber hasPrefix:@"1"]) {
    phoneNumber = [NSString stringWithFormat:@"1%@", phoneNumber];
  }
  phoneNumber = [NSString stringWithFormat:@"+%@", phoneNumber];
  return phoneNumber;
}

@end
