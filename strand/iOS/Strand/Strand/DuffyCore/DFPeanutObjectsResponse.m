//
//  DFPeanutSearchResponse.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutObjectsResponse.h"
#import <RestKit/RestKit.h>
#import "DFPeanutSuggestion.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFPeanutPhoto.h"

@implementation DFPeanutObjectsResponse

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects"
                                                 mapping:[DFPeanutFeedObject objectMapping]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys {
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
