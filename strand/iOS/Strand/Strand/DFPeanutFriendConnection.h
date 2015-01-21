//
//  DFPeanutFriendConnection.h
//  Strand
//
//  Created by Derek Parham on 1/21/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutFriendConnection : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber *id;
@property (nonatomic, retain) NSNumber *user_1;
@property (nonatomic, retain) NSNumber *user_2;

@end
