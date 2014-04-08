//
//  DFUser.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUser.h"
#import <AdSupport/ASIdentifierManager.h>
#import "DFNetworkingConstants.h"

@implementation DFUser

@synthesize hardwareDeviceID = _hardwareDeviceID, userID = _userID;

static NSString *DFUserIDUserDefaultsKey = @"com.duffysoft.DFUserIDUserDefaultsKey";
static NSString *DFOverrideDeviceIDUserDefaultsKey = @"com.duffysoft.DFOverrideDeviceIDUserDefaultsKey";
static NSString *DFOverrideServerURLKey = @"com.duffysoft.DFOverrideServerURLKey";
static NSString *DFOverrideServerPortKey = @"com.duffysoft.DFOverrideServerPortKey";

static DFUser *currentUser;

+ (DFUser *)currentUser
{
    if (!currentUser) {
        currentUser = [[super allocWithZone:nil] init];
    }
    return currentUser;
}

- (NSString *)deviceID
{
    if (self.userOverriddenDeviceID) return self.userOverriddenDeviceID;
    return self.hardwareDeviceID;
}

- (NSString *)hardwareDeviceID
{
    if (!_hardwareDeviceID && self == [DFUser currentUser]) {
        NSUUID *oNSUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
        _hardwareDeviceID = [oNSUUID UUIDString];
    }
    
    return _hardwareDeviceID;
}

- (void)setHardwareDeviceID:(NSString *)hardwareDeviceID
{
    if (self == [DFUser currentUser]) {
        [NSException raise:@"Cannot set hardwareDeviceID for current user." format:@""];
    }
    _hardwareDeviceID = hardwareDeviceID;
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
    if (!_userID && self == [DFUser currentUser]) {
        _userID = [[NSUserDefaults standardUserDefaults] valueForKey:DFUserIDUserDefaultsKey];
    }
    
    return _userID;
}

- (void)setUserID:(NSString *)userID
{
    _userID = userID;
    if (self == [DFUser currentUser]) {
        [[NSUserDefaults standardUserDefaults] setObject:userID forKey:DFUserIDUserDefaultsKey];
    }
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
        URLString = DFServerBaseURL;
    }
    
    if (self.userOverriddenServerPortString && ![self.userOverriddenServerPortString isEqualToString:@""]) {
        URLString = [NSString stringWithFormat:@"%@:%@", URLString, self.userOverriddenServerPortString];
    }
    
    return [NSURL URLWithString:URLString];
}

@end
