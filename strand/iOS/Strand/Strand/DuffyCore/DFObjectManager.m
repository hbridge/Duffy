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
#import "DFAppInfo.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"

static NSMutableSet *registeredAdapters;

@implementation DFObjectManager

NSString *const BuildOSKey = @"build_os";
NSString *const BuildNumberKey = @"build_number";
NSString *const BuildIDKey = @"build_id";

+ (void)initialize
{
  RKObjectManager* objectManager = [RKObjectManager managerWithBaseURL:[[DFUser currentUser] apiURL]];
  [RKObjectManager setSharedManager:objectManager];
  [[objectManager HTTPClient] setDefaultHeader:@"Accept-Encoding" value:@"gzip, deflate"];
  [[RKObjectManager sharedManager] setRequestSerializationMIMEType:RKMIMETypeJSON];
  //[[[[RKObjectManager sharedManager] HTTPClient] operationQueue] setMaxConcurrentOperationCount:1];
  DDLogDebug(@"HTTP client max ops: %d", (int)[[[[RKObjectManager sharedManager] HTTPClient] operationQueue] maxConcurrentOperationCount]);
  //  [RKObjectMapping setPreferredDateFormatter:[NSDateFormatter DjangoDateFormatter]];
  
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
  if ([[DFUser currentUser] userID]) {
    cumulativeParameters[DFUserIDParameterKey] = [NSNumber numberWithUnsignedLongLong:
                                                  [[DFUser currentUser] userID]];
  }
  if (([[DFUser currentUser] authToken])) {
    cumulativeParameters[DFAuthTokenParameterKey] = [[DFUser currentUser] authToken];
  }
  
  [cumulativeParameters addEntriesFromDictionary:@{
                                                   BuildOSKey: [DFAppInfo deviceAndOSVersion],
                                                   BuildNumberKey: [DFAppInfo buildNumber],
                                                   BuildIDKey: [DFAppInfo buildID],
                                                   }];
  
  [cumulativeParameters addEntriesFromDictionary:parameters];
  
  return [[RKObjectManager sharedManager] requestWithObject:object
                                                     method:method
                                                       path:path
                                                 parameters:cumulativeParameters];
  
}


@end
