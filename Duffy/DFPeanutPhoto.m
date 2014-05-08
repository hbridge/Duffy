//
//  DFPeanutPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 5/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutPhoto.h"
#import "DFPhoto.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSDictionary+DFJSON.h"
#import <RestKit/RestKit.h>
#import "DFFaceFeature.h"
#import "DFPeanutFaceFeature.h"
#import "DFUser.h"

@implementation DFPeanutPhoto

NSString const *DFPeanutPhotoImageDimensionsKey = @"DFPeanutPhotoImageDimensionsKey";
NSString const *DFPeanutPhotoImageBytesKey = @"DFPeanutPhotoImageBytesKey";

- (id)initWithDFPhoto:(DFPhoto *)photo
{
  self = [super init];
  if (self) {
    @autoreleasepool {
      self.user = [NSNumber numberWithUnsignedLongLong:photo.userID];
      if ([self.user isEqualToNumber:@(0)]) {
        DDLogWarn(@"DFPeanutPhoto initWithDFPhoto UserID=0");
        self.user = @([[DFUser currentUser] userID]);
      }
      self.id = [NSNumber numberWithUnsignedLongLong:photo.photoID];
      NSDateFormatter *djangoFormatter = [NSDateFormatter DjangoDateFormatter];
      self.time_taken = [djangoFormatter stringFromDate:photo.creationDate];
      self.metadata = photo.metadataDictionary;
      if (!photo.creationHashString || [photo.creationHashString isEqualToString:@""]) {
        [NSException raise:@"No hash" format:@"Cannot create a DFPeanutPhoto from DFPhoto with no creation hash."];
      }
      self.iphone_hash = photo.creationHashString;
      self.file_key = photo.objectID.URIRepresentation;
      if (photo.faceFeatureSources != DFFaceFeatureDetectionNone) {
        self.iphone_faceboxes_topleft = [DFPeanutFaceFeature
                                         peanutFaceFeaturesFromDFFaceFeatures:photo.faceFeatures];
      }
    }
  }
  return self;
}


+ (NSArray *)attributes
{
  return @[@"user", @"id", @"time_taken", @"metadata", @"iphone_hash", @"file_key", @"thumb_filename",
           @"full_filename"];
}

- (NSDictionary *)dictionaryForAttributes:(NSArray *)attributes
{
  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  for (NSString *key in attributes) {
    id value = [self valueForKey:key];
    if (value) {
      if ([[value class] isSubclassOfClass:[NSURL class]]) {
        result[key] = [(NSURL *)value absoluteString];
      } else {
        result[key] = [self valueForKey:key];
      }
    }
  }
  
  NSMutableSet *faceFeatureDicts = [[NSMutableSet alloc] init];
  for (DFPeanutFaceFeature *peanutFaceFeature in self.iphone_faceboxes_topleft) {
    [faceFeatureDicts addObject:peanutFaceFeature.dictionary];
  }
  result[@"iphone_faceboxes_topleft"] = faceFeatureDicts;
  
  return result;
}

- (NSDictionary *)dictionary
{
  return [self dictionaryForAttributes:[DFPeanutPhoto attributes]];
}

- (NSString *)JSONString
{
  NSDictionary *JSONSafeDict = [[self dictionary] dictionaryWithNonJSONRemoved];
  return [JSONSafeDict JSONString];
}

- (NSUInteger)metadataSizeBytes
{
  NSUInteger result = 0;
  @autoreleasepool {
    NSString *metadataJSONString = [self JSONString];
    result += [[metadataJSONString dataUsingEncoding:NSUTF8StringEncoding] length];
  }
  return result;
}

- (NSString *)photoUploadJSONString
{
  NSDictionary *JSONSafeDict = [[self dictionaryForAttributes:@[@"id", @"user", @"iphone_hash", @"file_key"]] dictionaryWithNonJSONRemoved];
  return [JSONSafeDict JSONString];
}

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFPeanutPhoto class]];
  [objectMapping addAttributeMappingsFromArray:[DFPeanutPhoto attributes]];
  
  [objectMapping addPropertyMapping:
   [RKRelationshipMapping relationshipMappingFromKeyPath:@"iphone_faceboxes_topleft"
                                               toKeyPath:@"iphone_faceboxes_topleft"
                                             withMapping:[DFPeanutFaceFeature objectMapping]]];
  
  return objectMapping;
}

- (NSString *)filename
{
  return [NSString stringWithFormat:@"%@.jpg", self.iphone_hash];
}

- (DFPhoto *)photoInContext:(NSManagedObjectContext *)context
{
  NSManagedObjectID *objectID = [context.persistentStoreCoordinator
                                 managedObjectIDForURIRepresentation:self.file_key];
  return (DFPhoto *)[context objectWithID:objectID];
}


- (NSString *)description
{
  return [NSString stringWithFormat:@"DFPeanutPhoto: {user:%d, id:%d, time_taken:%@, iphone_hash:%@, file_key:%@, metadata:%@, thumb_filename:%@ full_filename:%@ iphone_faceboxes_topleft:%@}",
          (int)self.user, (int)self.id, self.time_taken, self.iphone_hash, self.file_key.absoluteString, self.metadata.description, self.thumb_filename, self.full_filename, self.iphone_faceboxes_topleft];
}

@end
