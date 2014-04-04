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
static NSString *DFOverrideDeviceIDUserDefaultsKey = @"com.duffysoft.DFOverrideDeviceIDUserDefaultsKey";

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
    NSString *userSetDeviceID = [self userOverriddenDeviceID];
    if (userSetDeviceID) return userSetDeviceID;
    
    return self.hardwareDeviceID;
}

- (NSString *)hardwareDeviceID
{
    NSUUID *oNSUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
    return [oNSUUID UUIDString];
}

- (NSString *)userOverriddenDeviceID
{
     NSString *userSetDeviceID = [[NSUserDefaults standardUserDefaults] valueForKey:DFOverrideDeviceIDUserDefaultsKey];
    if (!userSetDeviceID || [userSetDeviceID isEqualToString:@""]) return nil;
    
    return userSetDeviceID;
}

- (void)setUserOverriddenDeviceID:(NSString *)userOverriddenDeviceID
{
    [[NSUserDefaults standardUserDefaults] setObject:userOverriddenDeviceID forKey:DFOverrideDeviceIDUserDefaultsKey];
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
