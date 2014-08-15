//
//  DFSocketsManager.h
//  Strand
//
//  Created by Derek Parham on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSocketsManager : NSObject <NSStreamDelegate>

+ (DFSocketsManager *)sharedManager;
- (void)initNetworkCommunication;
- (void)sendMessage:(NSString *)message;
@end
