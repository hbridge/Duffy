//
//  DFPeanutSharedStrand.h
//  Strand
//
//  Created by Derek Parham on 12/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutSharedStrand : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber *id;
@property (nonatomic, retain) NSArray *users;
@property (nonatomic) NSNumber *strand;

@end
