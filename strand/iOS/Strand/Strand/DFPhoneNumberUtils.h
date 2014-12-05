//
//  DFPhoneNumberUtils.h
//  Strand
//
//  Created by Henry Bridge on 12/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFPhoneNumberUtils : NSObject

// Get phone number into the format of +15551234567
+ (NSString *)normalizePhoneNumber:(NSString *)phoneNumber;

@end
