//
//  DFPeanutContact.h
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

#import "RestKit/RestKit.h"

@interface DFPeanutContact : NSObject <DFPeanutObject>

@property (nonatomic) NSNumber *id;
@property (nonatomic) NSNumber *user;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *phone_number;


@end
