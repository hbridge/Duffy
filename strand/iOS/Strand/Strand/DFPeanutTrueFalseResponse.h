//
//  DFPeanutTrueFalseResponse.h
//  Strand
//
//  Created by Henry Bridge on 6/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutTrueFalseResponse : NSObject <DFPeanutObject>

@property (nonatomic) BOOL result;
@property (nonatomic, retain) NSArray *invalid_fields;

- (NSString *)firstInvalidFieldDescription;
@end
