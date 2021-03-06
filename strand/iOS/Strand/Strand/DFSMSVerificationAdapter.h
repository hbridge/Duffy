//
//  DFSMSVerificationAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutTrueFalseResponse.h"

typedef void (^DFPeanutSMSVerificationRequestCompletionBlock)(DFPeanutTrueFalseResponse *response, NSError *error);

@interface DFSMSVerificationAdapter : NSObject <DFNetworkAdapter>

- (void)requestSMSCodeForPhoneNumber:(NSString *)phoneNumberString
                 withCompletionBlock:(DFPeanutSMSVerificationRequestCompletionBlock)completionBlock;

@end
