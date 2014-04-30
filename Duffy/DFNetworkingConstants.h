//
//  DFNetworkingConstants.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFNetworkingConstants : NSObject

extern NSString *DFServerBaseURL;
extern NSString *DFServerAPIPath;


// common parameters
extern NSString *DFUserIDParameterKey;
extern NSString *DFDeviceIDParameterKey;

// User ID constants
extern NSString *DFGetUserPath;
extern NSString *DFCreateUserPath;
extern NSString *DFDeviceNameParameterKey;

@end
