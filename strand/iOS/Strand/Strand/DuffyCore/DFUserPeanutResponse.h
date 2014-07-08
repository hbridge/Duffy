//
//  DFUserPeanutResponse.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFPeanutUserObject.h"

@interface DFUserPeanutResponse : NSObject <DFPeanutObject>

@property (nonatomic) BOOL result;
@property (nonatomic, retain) NSString *debug;
@property (nonatomic, retain) DFPeanutUserObject *user;

@end
