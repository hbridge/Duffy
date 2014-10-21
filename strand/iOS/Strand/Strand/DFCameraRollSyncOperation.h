//
//  DFCameraRollSyncOperation.h
//  Duffy
//
//  Created by Henry Bridge on 5/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DFPhotoCollection.h"

static int NumChangesFlushThreshold = 100;

@interface DFCameraRollSyncOperation : NSOperation

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) DFPhotoCollection *knownPhotos;
@property (nonatomic) dispatch_semaphore_t enumerationCompleteSemaphore;
@property (nonatomic, retain) NSMutableSet *foundURLs;
@property (nonatomic, retain) NSMutableSet *knownNotFoundURLs;
@property (nonatomic, retain) NSMutableDictionary *knownAndFoundURLsToDates;
@property (nonatomic, retain) NSMutableDictionary *allObjectIDsToChanges;
@property (nonatomic, retain) NSMutableDictionary *unsavedObjectIDsToChanges;
@property (nonatomic, retain) NSDate *targetDate;
@property (copy)void (^completionBlockWithChanges)(NSDictionary *);

- (NSDictionary *)mapKnownPhotoURLsToDates:(DFPhotoCollection *)knownPhotos;
- (void)flushChanges;
- (void)saveChanges:(NSDictionary *)changes;
- (NSDictionary *)changeTypesToCountsForChanges:(NSDictionary *)changes;
- (NSDictionary *)removePhotosNotFound:(NSSet *)photoURLsNotFound;

// To be overridden
- (NSDictionary *)findAssetChanges;
- (NSDictionary *)findAssetChangesBetweenTimes:(NSDate *)startDate beforeEndDate:(NSDate *)endDate;
- (NSArray *)photosToRemove:(NSSet *)photoURLsNotFound;
- (void)migrateAssets;
@end
