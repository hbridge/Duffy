//
//  DFPeanutAutocompleteResponse.h
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectMapping;

@interface DFPeanutAutocompleteResponse : NSObject

@property (nonatomic) float query_time;
@property (nonatomic) NSArray *results;

+ (RKObjectMapping *)objectMapping;

@end
