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
@property (readonly, nonatomic, retain) NSString *hardwareDeviceID;
@property (nonatomic, retain) NSString *userOverriddenDeviceID;
@property (nonatomic, retain) NSString *userID;

+ (DFUser *)currentUser;

@end
