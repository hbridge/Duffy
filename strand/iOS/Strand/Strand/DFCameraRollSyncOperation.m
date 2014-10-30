//
//  DFCameraRollSyncOperation.m
//  Duffy
//
//  Created by Henry Bridge on 5/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncOperation.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "DFPhotoCollection.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"
#import "DFDataHasher.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFCameraRollPhotoAsset.h"
#import "ALAsset+DFExtensions.h"
#import "DFAssetCache.h"

@interface DFCameraRollSyncOperation()

@end

@implementation DFCameraRollSyncOperation

- (void)main
{
  @autoreleasepool {
    DDLogInfo(@"%@ main beginning.", self.class);
    if (self.isCancelled) {
      [self cancelled];
      return;
    }

    [self migrateAssets];

    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    self.knownPhotos = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
    
    NSDictionary *objectIDsToChanges;
    if (self.targetDate) {
      NSTimeInterval secondsPerDay = 24 * 60 * 60;
      NSDate *dayBefore, *dayAfter;
      
      dayBefore = [self.targetDate dateByAddingTimeInterval: -secondsPerDay];
      dayAfter = [self.targetDate dateByAddingTimeInterval: secondsPerDay];
      
      DDLogInfo(@"Doing a camera roll sync between %@ and %@", dayBefore, dayAfter);
      objectIDsToChanges = [self findAssetChangesBetweenTimes:dayBefore beforeEndDate:dayAfter];
    } else {
      objectIDsToChanges = [self findAssetChanges];
    }

    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    // gather info about total changes then send notification that a scan completed
    //NSDictionary *changeTypesToCounts = [self changeTypesToCountsForChanges:changes];
    //NSUInteger numAdded = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeAdded] unsignedIntegerValue];
    //NSUInteger numDeleted = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeRemoved] unsignedIntegerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFCameraRollSyncCompleteNotificationName
       object:self];
    });
    
    if (self.completionBlockWithChanges) {
      self.completionBlockWithChanges(objectIDsToChanges);
    }
    DDLogInfo(@"%@ main ended.", self.class);
  }
}

- (void)cancelled
{
  DDLogInfo(@"%@ cancelled.  Stopping.", self.class);
}

- (NSDictionary *)mapKnownPhotoURLsToDates:(DFPhotoCollection *)knownPhotos
{
  NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
  
  for (DFPhoto *photo in [knownPhotos photoSet]) {
    mapping[photo.asset.canonicalURL] =
    [photo utcCreationDate];
  }
  
  return mapping;
}

- (NSDictionary *)findAssetChanges
{
  return [self findAssetChangesBetweenTimes:nil beforeEndDate:nil];
}

- (NSDictionary *)removePhotosNotFound:(NSSet *)photoURLsNotFound
{
  DDLogInfo(@"%lu photos in DB not present on device.", (unsigned long)photoURLsNotFound.count);
  NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
  
  NSArray *photosToRemove = [self photosToRemove:photoURLsNotFound];
  
  for (DFPhoto *photo in photosToRemove) {
    objectIDsToChanges[photo.objectID] = DFPhotoChangeTypeRemoved;
    [self.managedObjectContext deleteObject:photo];
  }
  
  return objectIDsToChanges;
}


- (void)flushChanges
{
  [self saveChanges:[self.unsavedObjectIDsToChanges copy]];
  [self.unsavedObjectIDsToChanges removeAllObjects];
}

- (void)saveChanges:(NSDictionary *)changes
{
  // save to the store so that the main thread context can pick it up
  NSError *error = nil;
  if (self.managedObjectContext.hasChanges) {
    DDLogInfo(@"%@ saving changes: \n%@ ",
              self.class,
              [self changeTypesToCountsForChanges:changes]);
    if(![self.managedObjectContext save:&error]) {
      DDLogError(@"%@ unresolved error %@, %@", self.class ,error, [error userInfo]);
      [NSException raise:@"Could not save camera roll sync changes."
                  format:@"Error: %@", [error localizedDescription]];
    } 
  }
}

- (NSDictionary *)changeTypesToCountsForChanges:(NSDictionary *)changes
{
  NSMutableDictionary *changeTypesToCounts = [[NSMutableDictionary alloc] init];
  for (NSString *changeType in @[DFPhotoChangeTypeAdded, DFPhotoChangeTypeMetadata, DFPhotoChangeTypeRemoved]) {
    NSSet *keysForType = [changes keysOfEntriesPassingTest:^BOOL(id key, NSString *changeTypeForKey, BOOL *stop) {
      if ([changeTypeForKey isEqualToString:changeType]) return YES;
      return NO;
    }];
    changeTypesToCounts[changeType] = [NSNumber numberWithUnsignedInteger:keysForType.count];
  }
  
  return changeTypesToCounts;
}

- (NSDictionary *)findAssetChangesBetweenTimes:(NSDate *)startDate beforeEndDate:(NSDate *)endDate;
{
  [DFCameraRollSyncOperation abstractClassError];
  return nil;
}

- (NSArray *)photosToRemove:(NSSet *)photoURLsNotFound
{
  [DFCameraRollSyncOperation abstractClassError];
  return nil;
}

- (void)migrateAssets
{
  [DFCameraRollSyncOperation abstractClassError];
}


+ (NSError *)abstractClassError
{
  return [NSError errorWithDomain:@"com.DuffyApp.DuffyCore"
                             code:-1
                         userInfo:@{NSLocalizedDescriptionKey: @"DFCameraRollSyncOperation is an abstract class. This method must be implemented"}];
}

- (NSManagedObjectContext *)managedObjectContext
{
  if (_managedObjectContext != nil) {
    return _managedObjectContext;
  }
  
  _managedObjectContext = [DFPhotoStore createBackgroundManagedObjectContext];
  return _managedObjectContext;
}

@end
