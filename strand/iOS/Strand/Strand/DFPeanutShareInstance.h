//
//  DFPeanutShareInstance.h
//  Strand
//
//  Created by Derek Parham on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutShareInstance : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber  *id;
@property (nonatomic, retain) NSNumber  *user;
@property (nonatomic, retain) NSNumber  *photo;
@property (nonatomic, retain) NSArray *users;

@end
