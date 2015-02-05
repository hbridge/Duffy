//
//  DFPeanutSearchResponse.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFPeanutFeedObject.h"
#import <EKObjectMapping.h>
#import <EKMappingProtocol.h>

@interface DFPeanutObjectsResponse : NSObject <EKMappingProtocol>

@property (nonatomic) BOOL result;
@property (nonatomic, retain) NSString *timestamp;
@property (nonatomic, retain) NSArray *objects;

- (NSArray *)topLevelSectionObjects;
- (NSArray *)topLevelObjectsOfType:(DFFeedObjectType)type;
+ (EKObjectMapping *)objectMapping;
+ (RKObjectMapping *)rkObjectMapping;

@end
