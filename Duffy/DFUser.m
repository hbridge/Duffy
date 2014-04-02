//
//  DFUser.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUser.h"
#import <AdSupport/ASIdentifierManager.h>

@implementation DFUser


static NSString *DFUserIDUserDefaultsKey = @"com.duffysoft.DFUserIDUserDefaultsKey";

static DFUser *currentUser;

+ (DFUser *)currentUser
{
    if (!currentUser) {
        currentUser = [[super allocWithZone:nil] init];
    }
    return currentUser;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self currentUser];
}

- (NSString *)deviceID
{
    NSUUID *oNSUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
    return [oNSUUID UUIDString];
}

- (NSString *)userID
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:DFUserIDUserDefaultsKey];
}

- (void)setUserID:(NSString *)userID
{
    [[NSUserDefaults standardUserDefaults] setObject:userID forKey:DFUserIDUserDefaultsKey];
}


@end
