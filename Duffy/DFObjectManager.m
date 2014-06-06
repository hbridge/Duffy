//
//  DFObjectManager.m
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFObjectManager.h"
#import <RestKit/RestKit.h>
#import "DFNetworkingConstants.h"
#import "DFPhotoStore.h"
#import "DFUser.h"

static NSMutableSet *registeredAdapters;

@implementation DFObjectManager


+ (void)initialize
{
    RKObjectManager* objectManager = [RKObjectManager managerWithBaseURL:[[DFUser currentUser] apiURL]];
    [RKObjectManager setSharedManager:objectManager];
  [[objectManager HTTPClient] setDefaultHeader:@"Accept-Encoding" value:@"gzip, deflate"];
    
    registeredAdapters = [[NSMutableSet alloc] init];
}


+ (void)registerAdapterClass:(Class <DFNetworkAdapter>)adapterClass
{
    if (![registeredAdapters containsObject:adapterClass]) {
        [[RKObjectManager sharedManager] addRequestDescriptorsFromArray:[adapterClass requestDescriptors]];
        [[RKObjectManager sharedManager] addResponseDescriptorsFromArray:[adapterClass responseDescriptors]];
        [registeredAdapters addObject:adapterClass];
    }
}

+ (RKObjectManager *)sharedManager
{
    return [RKObjectManager sharedManager];
}

+ (NSMutableURLRequest *)requestWithObject:(id)object
                                    method:(RKRequestMethod)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters
{
  NSMutableDictionary *cumulativeParameters = [[NSMutableDictionary alloc] init];
  cumulativeParameters[DFUserIDParameterKey] = [NSNumber numberWithUnsignedLongLong:
                                      [[DFUser currentUser] userID]];
  [cumulativeParameters addEntriesFromDictionary:parameters];
  
  return [[RKObjectManager sharedManager] requestWithObject:object
                                                     method:method
                                                       path:path
                                                 parameters:cumulativeParameters];
}


@end
