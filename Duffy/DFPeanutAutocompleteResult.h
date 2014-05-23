//
//  DFPeanutAutocompleteResult.h
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectMapping;

@interface DFPeanutAutocompleteResult : NSObject

@property (nonatomic) unsigned int count;
@property (nonatomic, retain) NSString *phrase;
@property (nonatomic) unsigned int order;

+ (RKObjectMapping *)objectMapping;


@end
