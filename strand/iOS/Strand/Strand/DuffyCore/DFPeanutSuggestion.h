//
//  DFPeanutSuggestion.h
//  Duffy
//
//  Created by Henry Bridge on 5/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RestKit.h>
#import "DFJSONConvertible.h"


@interface DFPeanutSuggestion : NSObject <DFJSONConvertible>

@property (nonatomic, retain) NSString *name;
@property (nonatomic) unsigned int count;
@property (nonatomic, retain) NSString *count_phrase;
@property (nonatomic) unsigned int order;

+ (RKObjectMapping *)objectMapping;

- (id)initWithJSONDict:(NSDictionary *)jsonDict;
- (NSDictionary *)JSONDictionary;
- (NSString *)JSONString;

@end
