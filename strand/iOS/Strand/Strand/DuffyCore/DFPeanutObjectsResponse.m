//
//  DFPeanutSearchResponse.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutObjectsResponse.h"
#import "DFPeanutSuggestion.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFPeanutPhoto.h"
#import "EKMappingBlocks+DFMappingBlocks.h"

@implementation DFPeanutObjectsResponse

+ (RKObjectMapping *)rkObjectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects"
                                                 mapping:[DFPeanutFeedObject rkObjectMapping]];
  
  return objectMapping;
}

+ (EKObjectMapping *)objectMapping {
  return [EKObjectMapping mappingForClass:self withBlock:^(EKObjectMapping *mapping) {
    [mapping mapPropertiesFromArray:[self simpleAttributeKeys]];

    [mapping hasMany:[DFPeanutFeedObject class] forKeyPath:@"objects"];
  }];
}


+ (NSArray *)simpleAttributeKeys {
  // Normally timestamp would be a date element, but in this case we consider it a string
  // since the client never looks at it, it simply passes it back to the server as is.
  return @[@"result", @"timestamp"];
}


- (NSArray *)topLevelSectionObjects
{
  return [self topLevelObjectsOfType:DFFeedObjectSection];
}

- (NSArray *)topLevelObjectsOfType:(DFFeedObjectType)type
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutFeedObject *searchObject in self.objects) {
    if ([searchObject.type isEqualToString:type]) {
      [result addObject:searchObject];
    }
  }
  return result;
}

@end
