//
//  DFPeanutInviteMessageResponse.h
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutInviteMessageResponse : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSString *invite_message;
@property (nonatomic) unsigned int invites_remaining;

@end
