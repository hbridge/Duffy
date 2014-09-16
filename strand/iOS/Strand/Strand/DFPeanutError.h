//
//  DFPeanutError.h
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutError : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *error_description;

@end
