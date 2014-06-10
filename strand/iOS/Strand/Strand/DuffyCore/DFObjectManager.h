//
//  DFObjectManager.h
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import <RestKit/RestKit.h>

@class RKObjectManager;

@interface DFObjectManager : NSObject

+ (void)registerAdapterClass:(Class <DFNetworkAdapter>)adapter;
+ (RKObjectManager *)sharedManager;
+ (NSMutableURLRequest *)requestWithObject:(id)object
                                    method:(RKRequestMethod)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters;

@end
