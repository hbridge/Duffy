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
NSString *DFOverrideServerURLKey = @"com.duffysoft.DFOverrideServerURLKey";
NSString *DFOverrideServerPortKey = @"com.duffysoft.DFOverrideServerPortKey";


static NSString *DefaultServerURL = @"http://asood123.no-ip.biz";

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

- (NSString *)userOverriddenServerURLKey
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:DFOverrideServerURLKey];
}

- (void)setUserOverriddenServerURLString:(NSString *)userOverriddenServerURLString
{
    [[NSUserDefaults standardUserDefaults] setObject:userOverriddenServerURLString forKey:DFOverrideServerURLKey];
}

- (NSString *)userOverriddenServerPortString
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:DFOverrideServerPortKey];
}

- (void)setUserOverriddenServerPortString:(NSString *)userOverriddenServerPortString
{
    [[NSUserDefaults standardUserDefaults] setObject:userOverriddenServerPortString forKey:DFOverrideServerPortKey];
}


- (NSURL *)serverURL
{
    NSString *URLString;
    if (self.userOverriddenServerURLString && ![self.userOverriddenServerURLString isEqualToString:@""]) {
        URLString = self.userOverriddenServerURLString;
    } else {
        URLString = DefaultServerURL;
    }
    
    if (self.userOverriddenServerPortString) {
        URLString = [NSString stringWithFormat:@"%@:%@", URLString, self.userOverriddenServerPortString];
    }
    
    return [NSURL URLWithString:URLString];
}

- (NSURL *)defaultServerURL
{
    return [NSURL URLWithString:DefaultServerURL];
}

- (NSString *)defaultServerPort
{
    return @"80";
}

@end
