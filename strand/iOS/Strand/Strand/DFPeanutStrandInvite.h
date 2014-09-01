//
//  DFPeanutStrandInvite.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutStrandInvite : NSObject <DFPeanutObject>

@property (nonatomic) NSNumber *strand;
@property (nonatomic) NSNumber *user;
@property (nonatomic, retain) NSString *phone_number;

@end
