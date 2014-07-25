//
//  DFUser.h
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUser : NSObject <NSCoding>

@property (nonatomic) DFUserIDType userID;
@property (nonatomic, retain) NSString *deviceID;
@property (nonatomic, retain) NSString *displayName;
@property (nonatomic, retain) NSString *authToken;
@property (nonatomic, retain) NSString *phoneNumberString;
@property (readonly, nonatomic) BOOL isUserDeveloper;

@property (readonly, nonatomic, retain) NSURL *serverURL;
@property (readonly, nonatomic, retain) NSURL *apiURL;
@property (readwrite, nonatomic, retain) NSString *userServerURLString;
@property (readwrite, nonatomic, retain) NSString *userServerPortString;

+ (DFUser *)currentUser;
+ (void)setCurrentUser:(DFUser *)user;

+ (NSString *)deviceName;
+ (NSString *)deviceNameBasedUserName;

@end
