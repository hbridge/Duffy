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
  return @[@"result", @"next_start_date_time"];
}


- (NSArray *)topLevelSectionNames
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutSearchObject *searchObject in self.objects) {
    if ([searchObject.type isEqualToString:DFSearchObjectSection]) {
      [result addObject:searchObject.title];
    }
  }
  return result;
}


+ (NSDictionary *)photosBySectionForSearchObjects:(NSArray *)peanutSearchObjects
{
  NSMutableDictionary *itemsBySectionResult = [[NSMutableDictionary alloc] init];
  for (DFPeanutSearchObject *sectionObject in peanutSearchObjects) {
    if ([sectionObject.type isEqualToString:DFSearchObjectSection]) {
      NSMutableArray *sectionItems = [[NSMutableArray alloc] init];
      
      for (DFPeanutSearchObject *searchObject in sectionObject.objects) {
        if ([searchObject.type isEqualToString:DFSearchObjectPhoto]){
          DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:searchObject.id];
          if (!photo) {
            photo = [DFPhoto createWithPhotoID:searchObject.id
                                     inContext:[[DFPhotoStore sharedStore] managedObjectContext]];
            photo.upload157Date = [NSDate date];
            photo.upload569Date = [NSDate date];
          }
          [sectionItems addObject:photo];
        } else if ([searchObject.type isEqualToString:DFSearchObjectCluster]
                   || [searchObject.type isEqualToString:DFSearchObjectDocstack]) {
          DFPhotoCollection *collection = [[DFPhotoCollection alloc]
                                           initWithPhotos:[self photosForCluster:searchObject]];
          [sectionItems addObject:collection];
        }
      }
      
      itemsBySectionResult[sectionObject.title] = sectionItems;
    }
  }
  
  [[DFPhotoStore sharedStore] saveContext];
  return itemsBySectionResult;
}

+ (NSArray *)photosForCluster:(DFPeanutSearchObject *)cluster
{
  NSMutableArray *photos = [[NSMutableArray alloc] init];
  for (DFPeanutSearchObject *subSearchObject in cluster.objects) {
    if ([subSearchObject.type isEqualToString:DFSearchObjectPhoto]) {
      DFPhoto *photo = [DFPhoto createWithPhotoID:subSearchObject.id
                               inContext:[[DFPhotoStore sharedStore] managedObjectContext]];
      photo.upload157Date = [NSDate date];
      photo.upload569Date = [NSDate date];
      [photos addObject:photo];
    }
  }
  
  return  photos;
}



@end
