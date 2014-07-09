//
//  DFPeanutMessageResponse.h
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutMessageResponse : NSObject <DFPeanutObject>

@property (nonatomic) BOOL result;
@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) NSArray *invalid_fields;

@end
