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
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"retry_suggestions"
                                                 mapping:[DFPeanutSuggestion objectMapping]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys {
  return @[@"result", @"next_start_date_time", @"thumb_image_path", @"full_image_path"];
}


- (NSArray *)topLevelSectionObjects
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutFeedObject *searchObject in self.objects) {
    if ([searchObject.type isEqualToString:DFFeedObjectSection]) {
      [result addObject:searchObject];
    }
  }
  return result;
}


@end
