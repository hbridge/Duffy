//
//  DFUser.h
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUser : NSObject

@property (readonly, nonatomic, retain) NSString *deviceID;
@property (nonatomic, retain) NSString *hardwareDeviceID;
@property (nonatomic, readonly) unsigned int devicePhysicalMemoryMB;
@property (nonatomic, retain) NSString *userOverriddenDeviceID;
@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSString *firstName;
@property (nonatomic, retain) NSString *lastName;

@property (readonly, nonatomic, retain) NSURL *serverURL;
@property (readonly, nonatomic, retain) NSURL *defaultServerURL;
@property (readwrite, nonatomic, retain) NSString *userOverriddenServerURLString;
@property (readwrite, nonatomic, retain) NSString *userOverriddenServerPortString;
@property (readonly, nonatomic, retain) NSString *defaultServerPort;


+ (DFUser *)currentUser;

@end
