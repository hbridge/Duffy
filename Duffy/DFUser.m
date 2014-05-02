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

static NSString *DFUserIDUserDefaultsKey = @"com.duffysoft.DFUserIDNumberUserDefaultsKey";
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

- (NSString *) deviceName
{
    return [[UIDevice currentDevice] name];
}

- (NSString *)userOverriddenDeviceID
{
    NSString *userSetDeviceID = [[NSUserDefaults standardUserDefaults] valueForKey:DFOverrideDeviceIDUserDefaultsKey];
    if (!userSetDeviceID || [userSetDeviceID isEqualToString:@""]) return nil;
    
    return userSetDeviceID;
}

- (void)setUserOverriddenDeviceID:(NSString *)userOverriddenDeviceID
{
    if (![userOverriddenDeviceID isEqualToString:self.userOverriddenDeviceID]) {
        [[NSUserDefaults standardUserDefaults] setObject:userOverriddenDeviceID forKey:DFOverrideDeviceIDUserDefaultsKey];
        // we set the user id to nil if the device is overriden, so that it will be refreshed on next load
        self.userID = 0;
    }
}

- (UInt64)userID
{
    if (!_userID && self == [DFUser currentUser]) {
        _userID = [(NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:DFUserIDUserDefaultsKey] unsignedLongLongValue];
    }
    
    return _userID;
}

- (void)setUserID:(UInt64)userID
{
    _userID = userID;
    if (self == [DFUser currentUser]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLongLong:userID] forKey:DFUserIDUserDefaultsKey];
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
    NSMutableString *URLString;
    if (self.userOverriddenServerURLString && ![self.userOverriddenServerURLString isEqualToString:@""]) {
        URLString = [self.userOverriddenServerURLString mutableCopy];
    } else {
        URLString = [DFServerBaseURL mutableCopy];
    }
    
    if (self.userOverriddenServerPortString && ![self.userOverriddenServerPortString isEqualToString:@""]) {
        [URLString appendString:[NSString stringWithFormat:@":%@", self.userOverriddenServerPortString]];
    }
    
    return [NSURL URLWithString:URLString];
}

- (NSURL *)apiURL
{
    return [[self serverURL] URLByAppendingPathComponent:DFServerAPIPath isDirectory:YES];
}


- (unsigned int) devicePhysicalMemoryMB
{
    unsigned long long memoryInBytes = [[NSProcessInfo processInfo] physicalMemory];
    return (unsigned int)(memoryInBytes/1000/1000);
}

@end
