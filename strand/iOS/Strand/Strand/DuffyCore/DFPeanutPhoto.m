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
#import "DFUser.h"

const int MaxUserCommentLength = 200;

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
      self.time_taken = [djangoFormatter stringFromDate:photo.utcCreationDate];
      self.local_time_taken = [djangoFormatter stringFromDate:photo.localCreationDate];
      self.metadata = [[self trimmedMetadataDict:photo.asset.metadata] JSONString];
      self.iphone_hash = photo.asset.hashString;
      self.file_key = photo.objectID.URIRepresentation;
      self.taken_with_strand = @((int)[photo.sourceString isEqualToString:@"strand"]);
    }
  }
  return self;
}

- (NSDictionary *)trimmedMetadataDict:(NSDictionary *)dictionary
{
  NSMutableDictionary *metadata = [[dictionary dictionaryWithNonJSONRemoved] mutableCopy];
  NSMutableDictionary *exif = [metadata[@"{Exif}"] mutableCopy];
  if (exif) {
    // the UserComment section of Exif data seems to be a dumping ground for app vendors
    // make sure it's within 200 chars
    NSString *userCommentString = exif[@"UserComment"];
    if (userCommentString.length > MaxUserCommentLength) {
      exif[@"UserComment"] = [userCommentString substringToIndex:MaxUserCommentLength];
      metadata[@"{Exif}"] = exif;
    }
  }
  
  return metadata;
}


+ (NSArray *)attributes
{
  return @[@"user", @"id", @"time_taken", @"local_time_taken", @"metadata", @"iphone_hash", @"file_key", @"thumb_filename",
           @"full_filename", @"full_image_path", @"taken_with_strand"];
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
  
  return result;
}

- (NSDictionary *)dictionary
{
  return [self dictionaryForAttributes:[DFPeanutPhoto attributes]];
}

- (NSDictionary *)metadataDictionary
{
  return [NSDictionary dictionaryWithJSONString:self.metadata];
}

- (NSString *)JSONString
{
  NSDictionary *JSONSafeDict = [[self dictionary] dictionaryWithNonJSONRemoved];
  NSString *result = [JSONSafeDict JSONString];
  
  if (result.length > 10000) DDLogWarn(@"DFPeanutPhoto JSONString > 10000 chars in length, string:%@", result);
  
  return result;
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
  return [NSString stringWithFormat:@"DFPeanutPhoto: {user:%d, id:%d, time_taken:%@, local_time_taken:%@, iphone_hash:%@, file_key:%@, metadata:%@, thumb_filename:%@ full_filename:%@ iphone_faceboxes_topleft:%@}",
          (int)self.user, (int)self.id, self.time_taken, self.local_time_taken, self.iphone_hash, self.file_key.absoluteString, self.metadata, self.thumb_filename, self.full_filename, self.iphone_faceboxes_topleft];
}

- (NSString *)thumbnail_image_path
{
  if (!_thumbnail_image_path) {
    NSString *directory = [self.full_image_path stringByDeletingLastPathComponent];
    return
    [directory stringByAppendingPathComponent:[NSString
                                               stringWithFormat:@"%@-thumb-156.jpg", self.id]];
  }
  
  return _thumbnail_image_path;
}

@end
