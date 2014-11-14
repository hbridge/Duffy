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
#import "DFPeanutUserObject.h"

@implementation DFUser

@synthesize userID = _userID;
@synthesize deviceID = _deviceID;
@synthesize userServerPortString = _userServerPortString;
@synthesize userServerURLString = _userServerURLString;

NSString *const userObjectDefaultsKey = @"com.duffysoft.User";

NSString *const DFOverrideServerURLKey = @"DFOverrideServerURLKey";
NSString *const DFOverrideServerPortKey = @"DFOverrideServerPortKey";

NSString *const userIDCodeKey = @"userID";
NSString *const deviceIDCodeKey = @"deviceID";
NSString *const displayNameCodeKey = @"displayName";
NSString *const authTokenCodeKey = @"authToken";
NSString *const phoneNumberCodeKey = @"phoneNumber";


NSString *DFEnabledYes = @"YES";
NSString *DFEnabledNo = @"NO";

static DFUser *currentUser;

+ (DFUser *)currentUser
{
  if (!currentUser) {
    [[NSUserDefaults standardUserDefaults] synchronize]; // ensure we get what's on disk
    NSData *userData = [[NSUserDefaults standardUserDefaults] valueForKey:userObjectDefaultsKey];
    if (userData) {
      currentUser = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
      DDLogInfo(@"%@ unarchiving user data: %@",
                [self.class description],
                currentUser.description);
    } else {
      currentUser = [[DFUser alloc] init];
      DDLogInfo(@"%@ no user data found.", [self.class description]);
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
  currentUser = user;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:user];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:userObjectDefaultsKey];
  // sync so we can be sure the user doesn't have to auth again if we crash etc
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSNumber *userIDNumber = [aDecoder decodeObjectForKey:userIDCodeKey];
    _userID = [userIDNumber longLongValue];
    NSString *deviceID = [aDecoder decodeObjectForKey:deviceIDCodeKey];
    if (deviceID) _deviceID = deviceID;
    _displayName = [aDecoder decodeObjectForKey:displayNameCodeKey];
    _authToken = [aDecoder decodeObjectForKey:authTokenCodeKey];
    _phoneNumberString = [aDecoder decodeObjectForKey:phoneNumberCodeKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:@(self.userID) forKey:userIDCodeKey];
  if (self != [DFUser currentUser]) {
    [aCoder encodeObject:self.deviceID forKey:deviceIDCodeKey];
  }
  if (self.displayName) [aCoder encodeObject:self.displayName forKey:displayNameCodeKey];
  if (self.authToken) [aCoder encodeObject:self.authToken forKey:authTokenCodeKey];
  if (self.phoneNumberString) [aCoder encodeObject:self.phoneNumberString forKey:phoneNumberCodeKey];
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

+ (NSString *)deviceNameBasedUserName
{
  NSString *name = [[UIDevice currentDevice] name];
  if (!name || [name isEqualToString:@""]) return @"";
  
  NSRange whitespaceRange = [name rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSRange punctuationRange = [name rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet]];
  NSUInteger firstLoc = MIN(whitespaceRange.location, punctuationRange.location);
  if (firstLoc != NSNotFound) {
    return [name substringToIndex:firstLoc];
  }
  
  return name;
}

- (BOOL)isUserDeveloper
{
#ifdef DEBUG
  return YES;
#else
  return NO;
#endif
}


#pragma mark - Server URL and port

- (NSString *)userServerURLString
{
  if (!_userServerURLString) {
    _userServerURLString = [[NSUserDefaults standardUserDefaults] objectForKey:DFOverrideServerURLKey];
  }
  
  return _userServerURLString;
}

- (void)setUserServerURLString:(NSString *)userServerURLString
{
  if (![userServerURLString isEqualToString:DFServerBaseURL]) {
    _userServerURLString = userServerURLString;
    DDLogInfo(@"Setting override server URL: %@", userServerURLString);
    [[NSUserDefaults standardUserDefaults] setObject:userServerURLString forKey:DFOverrideServerURLKey];
    BOOL result = [[NSUserDefaults standardUserDefaults] synchronize];
    DDLogInfo(@"Settings override write: %d", result);
    DDLogInfo(@"Object for key: %@", [[NSUserDefaults standardUserDefaults] objectForKey:DFOverrideServerURLKey]);
  }
}

- (NSString *)userServerPortString
{
  if (!_userServerPortString) {
    _userServerPortString = [[NSUserDefaults standardUserDefaults] stringForKey:DFOverrideServerPortKey];
  }
  return _userServerPortString;
}

- (void)setUserServerPortString:(NSString *)userServerPortString
{
  _userServerPortString = userServerPortString;
  DDLogInfo(@"Setting override port: %@", userServerPortString);
  [[NSUserDefaults standardUserDefaults] setObject:userServerPortString
                                            forKey:DFOverrideServerPortKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}


- (NSURL *)serverURL
{
  NSMutableString *URLString;
  if (self.userServerURLString && ![self.userServerURLString isEqualToString:@""]) {
    URLString = [self.userServerURLString mutableCopy];
  } else {
    URLString = [DFServerBaseURL mutableCopy];
  }
  
  if (self.userServerPortString && ![self.userServerPortString isEqualToString:@""]) {
    [URLString appendString:[NSString stringWithFormat:@":%@", self.userServerPortString]];
  }
  
  return [NSURL URLWithString:URLString];
}

- (NSURL *)apiURL
{
  return [[self serverURL] URLByAppendingPathComponent:DFServerAPIPath isDirectory:NO];
}


- (NSString *)description
{
  return [NSString stringWithFormat:@"{\n id: %llu\n deviceID: %@ \n displayName: %@\n authToken:%@\n } ",
          self.userID, self.deviceID, self.displayName, self.authToken];
}

- (DFPeanutUserObject *)peanutUser
{
  DFPeanutUserObject *peanutUser = [[DFPeanutUserObject alloc] init];
  peanutUser.id = self.userID;
  peanutUser.phone_number = self.phoneNumberString;
  peanutUser.display_name = self.displayName;
  return peanutUser;
}

@end
