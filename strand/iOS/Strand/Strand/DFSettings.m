//
//  DFSettings.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettings.h"
#import "DFAppInfo.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIAlertView+DFHelpers.h"

NSString *const AutosaveToCameraRollDefaultsKey = @"DFSettingsAutosaveToCameraRoll";

@interface DFSettings ()

@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;

@end

@implementation DFSettings

static DFSettings *defaultSettings;

@synthesize userAdapter = _userAdapter;

+ (DFSettings *)sharedSettings
{
  if (!defaultSettings) {
    defaultSettings = [[super allocWithZone:nil] init];
  }
  return defaultSettings;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedSettings];
}

/*
  Called when the display name is changed, want to save new name locally and on server.
  */
- (void)setDisplayName:(NSString *)displayName
{
  DFUser *currentUser = [DFUser currentUser];
  // Save copy of string incase there's a failure
  NSString *oldDisplayName = currentUser.displayName;
  
  // This updates the local user data so the UI is correct
  currentUser.displayName = displayName;
  
  // Create a PeanutUser to use for sending to the server, set only the display name
  DFPeanutUserObject *peanutUser = [[DFPeanutUserObject alloc] init];
  peanutUser.id = currentUser.userID;
  peanutUser.display_name = displayName;
  
  // Do the HTTP PUT to the server
  [self.userAdapter
   performRequest:RKRequestMethodPUT
   withPeanutUser:peanutUser
   success:^(DFPeanutUserObject *user) {
     // This writes the settings to local disk since the server returned success
     [DFUser setCurrentUser:currentUser];
     DDLogInfo(@"Successfully updated user object on server after display name change");
   }
   failure:^(NSError *error) {
     // Revert local user copy back to old data
     currentUser.displayName = oldDisplayName;
     DDLogError(@"%@ put of user object %@ failed with error: %@",
                [self.class description],
                peanutUser,
                error.description);
     [UIAlertView showSimpleAlertWithTitle:@"Error"
                                   message:[NSString stringWithFormat:
                                            @"Could not update display name. %@",
                                            error.localizedDescription]];
   }];
}

- (NSString *)displayName
{
  return [[DFUser currentUser] displayName];
}

- (NSString *)version
{
  return [DFAppInfo appInfoString];
}

- (NSString *)phoneNumber
{
  return [[DFUser currentUser] phoneNumberString];
}

- (BOOL)autosaveToCameraRoll
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:AutosaveToCameraRollDefaultsKey];
}

- (void)setAutosaveToCameraRoll:(BOOL)autosaveToCameraRoll
{
  if (autosaveToCameraRoll) {
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusAuthorized) {
      [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                              forKey:AutosaveToCameraRollDefaultsKey];
    } else if (status == ALAuthorizationStatusDenied) {
      [UIAlertView showSimpleAlertWithTitle:@"Enable Access"
                                    message:@"Please give this app permission to access your photo library in Settings."];
    } else if (status == ALAuthorizationStatusRestricted) {
      [UIAlertView showSimpleAlertWithTitle:@"Restricted"
                                    message:@"Cannot enable.  Access to the photo library is restricted on this phone."];
    } else if (status == ALAuthorizationStatusNotDetermined) {
      ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
      
      [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      } failureBlock:^(NSError *error) {
        if (error) {
          [UIAlertView showSimpleAlertWithTitle:@"Error"
                                        message:[NSString stringWithFormat:@"Cannot enable: %@",
                                                 error.localizedDescription]];
          DDLogWarn(@"Couldn't access camera roll, code: %ld", (long)error.code);
        }else{
          [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                                  forKey:AutosaveToCameraRollDefaultsKey];
        }
      }];
    }
  } else {
    [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                          forKey:AutosaveToCameraRollDefaultsKey];
  }
}


- (NSString *)serverURL
{
  NSString *urlString = [[DFUser currentUser] userServerURLString];
  return urlString;
}

- (void)setServerURL:(NSString *)newURL
{
  [[DFUser currentUser] setUserServerURLString:newURL];
}

- (NSString *)serverPort
{
  return [[DFUser currentUser] userServerPortString];
}

- (void)setServerPort:(NSString *)serverPort
{
  [[DFUser currentUser] setUserServerPortString:serverPort];
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) _userAdapter = [[DFUserPeanutAdapter alloc] init];
  return _userAdapter;
}



@end
