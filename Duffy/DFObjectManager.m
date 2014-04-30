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
    RKObjectManager* objectManager = [RKObjectManager managerWithBaseURL:[[DFUser currentUser] serverURL]];
    [RKObjectManager setSharedManager:objectManager];
    
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

@end
