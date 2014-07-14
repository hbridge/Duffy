//
//  DFPeanutErrorResponse.h
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutInvalidField : NSObject <DFPeanutObject>
@property (nonatomic, retain) NSString *field_name;
@property (nonatomic, retain) NSArray *field_errors;


+ (NSError *)invalidFieldsErrorForError:(NSError *)error;

@end

