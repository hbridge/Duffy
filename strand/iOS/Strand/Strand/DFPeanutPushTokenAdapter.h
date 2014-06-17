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

typedef enum
{
  DFBuildTypeDebug = 0,
  DFBuildTypeAdHoc = 1,
  DFBuildTypeProd = 2,
} DFBuildType;

@interface DFPeanutPushTokenAdapter : NSObject <DFNetworkAdapter>


- (void)registerAPNSToken:(NSData *)apnsToken
             forBuildType:(DFBuildType)buildType
          completionBlock:(DFPushTokenResponseBlock)completionBlock;
@end
