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

@synthesize userID = _userID;
@synthesize deviceID = _deviceID;

NSString *const userObjectDefaultsKey = @"com.duffysoft.User";

static NSString *DFOverrideServerURLKey = @"com.duffysoft.DFOverrideServerURLKey";
static NSString *DFOverrideServerPortKey = @"com.duffysoft.DFOverrideServerPortKey";

NSString *const userIDCodeKey = @"dserID";
NSString *const deviceIDCodeKey = @"deviceID";
NSString *const firstNameCodeKey = @"firstName";
NSString *const lastNameCodeKey = @"lastName";
NSString *const authTokenCodeKey = @"authToken";



NSString *DFEnabledYes = @"YES";
NSString *DFEnabledNo = @"NO";

static DFUser *currentUser;

+ (DFUser *)currentUser
{
  if (!currentUser) {
    NSData *userData = [[NSUserDefaults standardUserDefaults] valueForKey:userObjectDefaultsKey];
    if (userData) {
      currentUser = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
    } else {
      currentUser = [[DFUser alloc] init];
    }
    
    [self checkUserDefaults];
  }
  return currentUser;
}

+ (void)checkUserDefaults
{
  
}

+ (void)setCurrentUser:(DFUser *)user
{
  DDLogInfo(@"Setting current user to: %@", user.description);
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:user];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:userObjectDefaultsKey];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSNumber *userIDNumber = [aDecoder decodeObjectForKey:userIDCodeKey];
    _userID = [userIDNumber longLongValue];
    NSString *deviceID = [aDecoder decodeObjectForKey:deviceIDCodeKey];
    if (deviceID) _deviceID = deviceID;
    _firstName = [aDecoder decodeObjectForKey:firstNameCodeKey];
    _lastName = [aDecoder decodeObjectForKey:lastNameCodeKey];
    _authToken = [aDecoder decodeObjectForKey:authTokenCodeKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:@(self.userID) forKey:userIDCodeKey];
  if (self != [DFUser currentUser]) {
    [aCoder encodeObject:self.deviceID forKey:deviceIDCodeKey];
  }
  if (self.firstName) [aCoder encodeObject:self.firstName forKey:_firstName];
  if (self.lastName) [aCoder encodeObject:self.lastName forKey:_lastName];
  if (self.authToken) [aCoder encodeObject:self.authToken forKey:_authToken];
}

- (void)setDeviceID:(NSString *)deviceID
{
  if (self == [DFUser currentUser]) {
    [NSException raise:@"Read only for current user" format:@"Cannot set device ID for current user"];
  } else {
    _deviceID = deviceID;
  }
}

- (NSString *)deviceID
{
  if (self == [DFUser currentUser]) {
    NSUUID *oNSUUID = [[UIDevice currentDevice] identifierForVendor];
    return [oNSUUID UUIDString];
  } else {
    return _deviceID;
  }
}

+ (NSString *) deviceName
{
  return [[UIDevice currentDevice] name];
}


#pragma mark - Server URL and port

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


- (NSString *)description
{
  return [NSString stringWithFormat:@"{\n id: %llu\n deviceID: %@, firstName: %@\n lastName: %@\n authToken:%@\n } ",
          self.userID, self.deviceID, self.firstName, self.lastName, self.authToken];
}



@end
