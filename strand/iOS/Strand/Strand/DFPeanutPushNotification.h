//
//  DFPeanutPushNotification.h
//  Strand
//
//  Created by Henry Bridge on 7/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFTypedefs.h"

@interface DFPeanutPushNotification : NSObject


@property (readonly, nonatomic, retain) NSString *message;
@property (readonly, nonatomic) DFScreenType screenToShow;
@property (readonly, nonatomic) BOOL contentAvailable;
@property (readonly, nonatomic) BOOL isUpdateLocationRequest;

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo;




@end
