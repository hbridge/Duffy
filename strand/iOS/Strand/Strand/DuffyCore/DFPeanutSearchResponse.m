//
//  DFPeanutSearchResponse.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutSearchResponse.h"
#import <RestKit/RestKit.h>
#import "DFPeanutSuggestion.h"
#import "DFPeanutSearchObject.h"
#import "DFPhotoStore.h"
#import "DFPeanutPhoto.h"

@implementation DFPeanutSearchResponse

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects"
                                                 mapping:[DFPeanutSearchObject objectMapping]];
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
  for (DFPeanutSearchObject *searchObject in self.objects) {
    if ([searchObject.type isEqualToString:DFSearchObjectSection]) {
      [result addObject:searchObject];
    }
  }
  return result;
}


@end
