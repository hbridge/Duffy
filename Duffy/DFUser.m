//
//  DFUser.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUser.h"
#import <AdSupport/ASIdentifierManager.h>

@implementation DFUser

+ (NSString *)deviceID
{
    NSUUID *oNSUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
    return [oNSUUID UUIDString];
}


@end
