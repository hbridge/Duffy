//
//  DFAppInfo.m
//  Duffy
//
//  Created by Henry Bridge on 5/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAppInfo.h"

@implementation DFAppInfo


+ (NSString *)appInfoString
{
  static NSString *appInfoString = nil;
  if (!appInfoString) {
    // App name
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
    
    // version and build type
    NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
    NSString *buildType;
#ifdef DEBUG
    buildType = @"debug";
#else
    buildType = @"release";
#endif
    return [NSString stringWithFormat:@"%@ %@ (%@) %@",
            appName ? appName : @"", majorVersion, minorVersion, buildType];
  }
  
  return appInfoString;
}


+ (NSNumber *)buildNumber
{
  static NSNumber *buildNumber = nil;
  if (!buildNumber) {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    buildNumber = @([[infoDictionary objectForKey:@"CFBundleVersion"] integerValue]);
  }
  return buildNumber;
}

+ (NSString *)buildID
{
  static NSString *buildID = nil;
  if (!buildID) {
    buildID = [[NSBundle mainBundle] bundleIdentifier];
  }
  return buildID;
}

+ (NSString *)deviceAndOSVersion
{
  static NSString *buildDeviceAndOS = nil;
  if (!buildDeviceAndOS) {
    buildDeviceAndOS = [NSString stringWithFormat:@"%@/%@",
                        [[UIDevice currentDevice] model],
                        [[UIDevice currentDevice] systemVersion]];
  }
  return buildDeviceAndOS;
}

@end
