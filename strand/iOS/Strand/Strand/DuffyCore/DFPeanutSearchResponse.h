//
//  DFPeanutSearchResponse.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutSearchResponse : NSObject <DFPeanutObject>

@property (nonatomic) BOOL result;
@property (nonatomic, retain) NSString *next_start_date_time;
@property (nonatomic, retain) NSArray *objects;
@property (nonatomic, retain) NSArray *retry_suggestions;
@property (nonatomic, retain) NSString *thumb_image_path;
@property (nonatomic, retain) NSString *full_image_path;

- (NSArray *)topLevelSectionObjects;

@end
