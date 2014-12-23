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

@property (nonatomic, retain) NSNumber *id;
@property (nonatomic) NSNumber *strand;
@property (nonatomic) NSNumber *share_instance;
@property (nonatomic) NSNumber *user;
@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSNumber *accepted_user;
@property (nonatomic, retain) NSNumber *invited_user;

@end
