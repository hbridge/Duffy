//
//  DFPeanutPushTokenAdapter.h
//  Strand
//
//  Created by Henry Bridge on 6/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"

typedef void (^DFPushTokenResponseBlock)(BOOL success);

@interface DFPeanutPushTokenAdapter : NSObject <DFNetworkAdapter>


- (void)registerAPNSToken:(NSData *)apnsToken
          completionBlock:(DFPushTokenResponseBlock)completionBlock;
@end
