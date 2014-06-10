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


NSString *DFAutoUploadEnabledUserDefaultKey = @"DFAutoUploadEnabledUserDefaultKey";
NSString *DFConserveDataEnabledUserDefaultKey = @"DFConserveDataEnabledUserDefaultKey";
NSString *DFEnabledYes = @"YES";
NSString *DFEnabledNo = @"NO";

static DFUser *currentUser;

+ (DFUser *)currentUser
{
    if (!currentUser) {
        currentUser = [[super allocWithZone:nil] init];
      [self checkUserDefaults];
    }
    return currentUser;
}

+ (void)checkUserDefaults
{
  if (![[NSUserDefaults standardUserDefaults] valueForKey:DFAutoUploadEnabledUserDefaultKey]){
    [[NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFAutoUploadEnabledUserDefaultKey];
  }
  
  if (![[NSUserDefaults standardUserDefaults] valueForKey:DFConserveDataEnabledUserDefaultKey]){
    [[NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFConserveDataEnabledUserDefaultKey];
  }
  [[NSUserDefaults standardUserDefaults] synchronize];
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
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLongLong:userID]
                                                  forKey:DFUserIDUserDefaultsKey];
    }
}

- (NSString *)userOverriddenServerURLKey
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:DFOverrideServerURLKey];
}

- (void)setUserOverriddenServerURLString:(NSString *)userOverriddenServerURLString
{
    [[NSUserDefaults standardUserDefaults] setObject:userOverriddenServerURLString forKey:DFOverrideServerURLKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)userOverriddenServerPortString
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:DFOverrideServerPortKey];
}

- (void)setUserOverriddenServerPortString:(NSString *)userOverriddenServerPortString
{
  [[NSUserDefaults standardUserDefaults] setObject:userOverriddenServerPortString
                                            forKey:DFOverrideServerPortKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
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
    return [[self serverURL] URLByAppendingPathComponent:DFServerAPIPath isDirectory:NO];
}


- (unsigned int) devicePhysicalMemoryMB
{
    unsigned long long memoryInBytes = [[NSProcessInfo processInfo] physicalMemory];
    return (unsigned int)(memoryInBytes/1000/1000);
}

- (BOOL)autoUploadEnabled
{
  if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFAutoUploadEnabledUserDefaultKey]
       isEqualToString:DFEnabledYes]){
    return YES;
  }
  
  return NO;
}

- (void)setAutoUploadEnabled:(BOOL)autoUploadEnabled
{
  if (autoUploadEnabled) {
    DDLogInfo(@"Auto-upload now ON");
    [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFAutoUploadEnabledUserDefaultKey];
  } else {
    DDLogInfo(@"Auto-upload now OFF");
    [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledNo forKey:DFAutoUploadEnabledUserDefaultKey];
  }
  [[NSUserDefaults standardUserDefaults] synchronize];
}


- (BOOL)conserveDataEnabled
{
  if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFConserveDataEnabledUserDefaultKey]
       isEqualToString:DFEnabledYes]){
    return YES;
  }
  
  return NO;
}

- (void)setConserveDataEnabled:(BOOL)conserveDataEnabled
{
  if (conserveDataEnabled) {
    DDLogInfo(@"Conserve cellular data now ON");
    [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFConserveDataEnabledUserDefaultKey];
  } else {
    DDLogInfo(@"Conserve cell data now OFF");
    [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledNo forKey:DFConserveDataEnabledUserDefaultKey];
  }
  
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"{\n firstName: %@ \n lastName:%@ \n id:%llu \n} ",
          self.firstName, self.lastName, self.userID];
}



@end
