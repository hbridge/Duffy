//
//  DFPeanutInviteMessageAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutInviteMessageResponse.h"

@interface DFPeanutInviteMessageAdapter : NSObject

typedef void (^DFPeanutInviteMessageResponseBlock)(DFPeanutInviteMessageResponse *response, NSError *error);

- (void)fetchInviteMessageResponse:(DFPeanutInviteMessageResponseBlock)completionBlock;

@end
