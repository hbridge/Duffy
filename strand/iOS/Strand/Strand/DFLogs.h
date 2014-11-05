//
//  DFLogs.h
//  Strand
//
//  Created by Henry Bridge on 11/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFLogs : NSObject

+ (NSData *)aggregatedLogData;
+ (NSString *)aggregatedLogString;

@end
