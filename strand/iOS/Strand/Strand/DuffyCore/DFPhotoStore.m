//
//  DFPhotoStore.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStore.h"
#import "DFPhotoStore+IntegrityCheck.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhoto.h"
#import "DFNotificationSharedConstants.h"
#import "UIImage+DFHelpers.h"

@interface DFPhotoStore(){
  NSManagedObjectContext *_managedObjectContext;
}

@property (nonatomic, retain) DFPhotoCollection *cameraRoll;
@property (nonatomic, retain) NSMutableDictionary *allDFAlbumsByName;

@end

@implementation DFPhotoStore

@synthesize assetsLibrary = _assetsLibrary;

static DFPhotoStore *defaultStore;

+ (DFPhotoStore *)sharedStore {
  if (!defaultStore) {
    defaultStore = [[super allocWithZone:nil] init];
  }
  return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedStore];
}


- (id)init
{
  self = [super init];
  if (self) {
    // do an integrity check
    DFPhotoStoreIntegrityCheckResult integrityResult =
    [self checkForErrorsAndRepairWithContext:[self managedObjectContext]];
    if (integrityResult == DFIntegrityResultErrorsFixed) {
      [self saveContext];
    } else if (integrityResult == DFIntegrityResultErrorsUnfixable) {
      DDLogError(@"Integrity check found errors it could not fix!");
    }
    
    // load photos that have already been imported
    _cameraRoll = [[DFPhotoCollection alloc] init];
    [self loadCameraRollDB];
    
    //register to hear about other context saves so we can merge in changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundContextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
    
    // register to hear about more fine grained photo notification changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(photosChanged:)
                                                 name:DFPhotoChangedNotificationName
                                               object:nil];
    
  }
  return self;
}


+ (NSManagedObjectContext *)createBackgroundManagedObjectContext
{
  NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
  managedObjectContext.persistentStoreCoordinator = [DFPhotoStore persistentStoreCoordinator];
  return managedObjectContext;
}

- (void)loadCameraRollDB
{
  self.cameraRoll = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
  
  [[NSNotificationCenter defaultCenter]
   postNotificationName:DFPhotoStoreCameraRollUpdatedNotificationName
   object:self];
}

+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context
                                              maxCount:(NSUInteger)maxCount
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  request.fetchLimit = maxCount;
  
  NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSSortDescriptor *dateSort = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES];
  request.sortDescriptors = [NSArray arrayWithObject:dateSort];
  
  NSError *error;
  NSArray *result = [context executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could not fetch photos"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return [[DFPhotoCollection alloc] initWithPhotos:result];
}

+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context
{
  return [DFPhotoStore allPhotosCollectionUsingContext:context maxCount:0];
}


+ (DFPhoto *)photoWithALAssetURLString:(NSString *)assetURLString context:(NSManagedObjectContext *)context;
{
  return [[self photosWithALAssetURLStrings:[NSArray arrayWithObject:assetURLString] context:context] firstObject];
}

static int const FetchStride = 500;

+ (NSArray *)photosWithValueStrings:(NSArray *)values
                             forKey:(NSString *)key
                   comparisonString:(NSString *)comparisonString
                          inContext:(NSManagedObjectContext *)context
{
  NSString *predicateFormat = [NSString stringWithFormat:@"%@ %@ %@",
                               key, comparisonString ? comparisonString : @"=", @"%@"];
  
  NSMutableArray *allObjects = [[NSMutableArray alloc] init];
  unsigned int numFetched = 0;
  while (numFetched < values.count) {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    NSMutableArray *predicates = [[NSMutableArray alloc] init];
    for (int i = numFetched; i < MIN(numFetched + FetchStride, values.count); i++) {
      NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat,
                                values[i]];
      [predicates addObject:predicate];
    }
    
    NSPredicate *orPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
    request.predicate = orPredicate;
    
    NSError *error;
    NSArray *result = [context executeFetchRequest:request error:&error];
    if (!result) {
      [NSException raise:@"Could search for photos"
                  format:@"Error: %@", error.description];
    }
    
    [allObjects addObjectsFromArray:result];
    numFetched += predicates.count; // we use the predicates count to avoid getting into an infinite loop
                                    // in case one of the search terms wasn't found in the DB
  }
  
  return allObjects;
}


+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;
{
  return [self photosWithValueStrings:assetURLStrings
                               forKey:@"alAssetURLString"
                     comparisonString:@"==[c]"
                            inContext:context];
}


+ (DFPhotoCollection *)photosWithPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  request.predicate = predicate;
  
  NSError *error;
  NSArray *result = [context executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could fetch photos"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return [[DFPhotoCollection alloc] initWithPhotos:result];
}

+ (NSArray *)photosWithPhotoIDs:(NSArray *)photoIDs
                    retainOrder:(BOOL)retainOrder
                      inContext:(NSManagedObjectContext *)context
{
  NSArray *results = [self photosWithValueStrings:photoIDs
                                           forKey:@"photoID"
                                 comparisonString:@"="
                                        inContext:context];
  if (results == nil || results.count == 0 || !retainOrder) return results;
  
  NSMutableDictionary *photoIDsToPhotos = [[NSMutableDictionary alloc] init];
  for (DFPhoto *photo in results) {
    photoIDsToPhotos[@(photo.photoID)] = photo;
  }
  NSMutableArray *sortedResults = [[NSMutableArray alloc] init];
  for (NSNumber *photoID in photoIDs) {
    DFPhoto *photo = photoIDsToPhotos[photoID];
    if (photo) {
      [sortedResults addObject:photo];
    } else {
      DDLogVerbose(@"Requested photo with id not found: %llu", photoID.longLongValue);
    }
  }
  
  return sortedResults;
}

- (NSArray *)photosWithPhotoIDs:(NSArray *)photoIDs retainOrder:(BOOL)retainOrder
{
  return [DFPhotoStore photosWithPhotoIDs:photoIDs
                              retainOrder:retainOrder
                                inContext:[self managedObjectContext]];
}

+ (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID inContext:(NSManagedObjectContext *)context
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"photoID == %llu", photoID];
  DFPhotoCollection *results = [DFPhotoStore photosWithPredicate:predicate inContext:context];
  if (results.photoSet.count > 1) {
    [NSException raise:@"Multiple photos matching ID" format:@"%lu photos matching id:%llu",
     (unsigned long)results.photoSet.count, photoID];
  } else if (results.photoSet.count == 0) {
    return nil;
  }
  
  return [[results photosByDateAscending:YES] firstObject];
}

- (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID
{
  return [DFPhotoStore photoWithPhotoID:photoID inContext:[self managedObjectContext]];
}

- (DFPhotoCollection *)mostRecentPhotos:(NSUInteger)maxCount
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  request.fetchLimit = maxCount;
  
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSSortDescriptor *dateSort = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO];
  request.sortDescriptors = [NSArray arrayWithObject:dateSort];
  
  NSError *error;
  NSArray *result = [[self managedObjectContext] executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could not fetch photos"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return [[DFPhotoCollection alloc] initWithPhotos:result];
}

- (DFPhoto *)mostRecentUploadedThumbnail
{
  
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
  request.predicate = [NSPredicate predicateWithFormat:@"upload157Date != nil"];
  request.fetchLimit = 1;
  
  NSError *error;
  NSArray *result = [[self managedObjectContext] executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could fetch photos"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  if (!result.count) return nil;
  
  return [result firstObject];
}

- (DFPhotoCollection *)photosWithThumbnailUploadStatus:(DFUploadStatus)thumbnailStatus
                                      fullUploadStatus:(DFUploadStatus)fullStatus
{
  return [DFPhotoStore photosWithThumbnailUploadStatus:thumbnailStatus
                                      fullUploadStatus:fullStatus
                                             inContext:[self managedObjectContext]];
}

+ (DFPhotoCollection *)photosWithThumbnailUploadStatus:(DFUploadStatus)thumbnailStatus
                                      fullUploadStatus:(DFUploadStatus)fullStatus
                                             inContext:(NSManagedObjectContext *)context;
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSPredicate *thumbnailPredicate;
  if (thumbnailStatus == DFUploadStatusUploaded) {
    thumbnailPredicate = [NSPredicate predicateWithFormat:@"upload157Date != nil"];
  } else if (thumbnailStatus == DFUploadStatusNotUploaded){
    thumbnailPredicate = [NSPredicate predicateWithFormat:@"upload157Date = nil"];
  }
  
  NSPredicate *fullPredicate;
  if (fullStatus == DFUploadStatusUploaded) {
    fullPredicate = [NSPredicate predicateWithFormat:@"upload569Date != nil"];
  } else if (fullStatus == DFUploadStatusNotUploaded) {
    fullPredicate = [NSPredicate predicateWithFormat:@"upload569Date = nil"];
  }
  
  assert(thumbnailPredicate || fullPredicate);
  
  NSMutableArray *subpredeicates = [NSMutableArray new];
  if (thumbnailPredicate) [subpredeicates addObject:thumbnailPredicate];
  if (fullPredicate) [subpredeicates addObject:fullPredicate];
  NSCompoundPredicate *compoundPredicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                       subpredicates:subpredeicates];
  request.predicate = compoundPredicate;
  
  NSError *error;
  NSArray *result = [context executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could search for photos."
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return [[DFPhotoCollection alloc] initWithPhotos:result];
}


+ (DFPhotoCollection *)photosWithFullPhotoUploadStatus:(BOOL)isUploaded inContext:(NSManagedObjectContext *)context
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSPredicate *predicate;
  if (isUploaded) {
    predicate = [NSPredicate predicateWithFormat:@"upload569Date != nil"];
  } else {
    predicate = [NSPredicate predicateWithFormat:@"upload569Date = nil"];
  }
  
  request.predicate = predicate;
  
  NSError *error;
  NSArray *result = [context executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could search for photos."
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return [[DFPhotoCollection alloc] initWithPhotos:result];
  
}



- (DFPhotoCollection *)cameraRoll
{
  return _cameraRoll;
}

- (NSSet *)photosWithObjectIDs:(NSSet *)objectIDs
{
  NSMutableSet *photos = [[NSMutableSet alloc] init];
  for (NSManagedObjectID *objectID in objectIDs) {
    NSError *error;
    DFPhoto *photo = (DFPhoto *)[self.managedObjectContext existingObjectWithID:objectID error:&error];
    if (error) {
      DDLogError(@"Error fetching photos with IDs: %@", error.localizedDescription);
    }
    if (photo != nil) {
      [photos addObject:photo];
    }
  }
  return photos;
}

#pragma mark - Assets Library

- (ALAssetsLibrary *)assetsLibrary
{
  if (_assetsLibrary == nil) {
    _assetsLibrary = [[ALAssetsLibrary alloc] init];
  }
  return _assetsLibrary;
}


#pragma mark - Notification handlers



/* Save notification handler for the background context */
- (void)backgroundContextDidSave:(NSNotification *)notification {
  /* Make sure we're on the main thread when updating the main context */
  if (![NSThread isMainThread]) {
    [self performSelectorOnMainThread:@selector(backgroundContextDidSave:)
                           withObject:notification
                        waitUntilDone:NO];
    return;
  }
  
  /* merge in the changes to the main context */
  [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}

- (void)photosChanged:(NSNotification *)note
{
  [note.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSString *changeType = (NSString *)obj;
    if ([changeType isEqualToString:DFPhotoChangeTypeAdded] || [changeType isEqualToString:DFPhotoChangeTypeRemoved]) {
      DDLogInfo(@"DFPhotoStore: notification indicates photo added or removed.  Reloading camera roll.");
      [self loadCameraRollDB];
      *stop = YES;
    }
  }];
}




- (void)clearUploadInfo
{
  DFPhotoCollection *allPhotosCollection = [DFPhotoStore allPhotosCollectionUsingContext:[self managedObjectContext]];
  for (DFPhoto *photo in allPhotosCollection.photoSet) {
    photo.upload157Date = nil;
    photo.upload569Date = nil;
    photo.photoID = 0;
  }
  
  [self saveContext];
}


#pragma mark - Core Data stack


// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
  if (![NSThread isMainThread]) {
    [NSException raise:@"DFPhotoStore managedObjectContext can only be accessed from main thread." format:nil];
  }
  if (_managedObjectContext != nil) {
    return _managedObjectContext;
  }
  
  NSPersistentStoreCoordinator *coordinator = [DFPhotoStore persistentStoreCoordinator];
  if (coordinator != nil) {
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
  }
  return _managedObjectContext;
}

static NSManagedObjectModel *_managedObjectModel = nil;
static NSPersistentStoreCoordinator *_persistentStoreCoordinator = nil;

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
+ (NSManagedObjectModel *)managedObjectModel
{
  if (_managedObjectModel != nil) {
    return _managedObjectModel;
  }
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Duffy" withExtension:@"momd"];
  _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (_persistentStoreCoordinator != nil) {
    return _persistentStoreCoordinator;
  }
  
  NSURL *storeURL = [[DFPhotoStore applicationDocumentsDirectory] URLByAppendingPathComponent:@"Duffy.sqlite"];
  
  NSError *error = nil;
  _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                 configuration:nil
                                                           URL:storeURL
                                                       options:nil//@{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
                                                         error:&error]) {
    
    DDLogError(@"Error loading persistent store %@, %@", error, [error userInfo]);
    error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    DDLogWarn(@"Deleted persistent store %@, error: %@", storeURL, error);
    error = nil;
    NSURL *storeShm = [[storeURL URLByDeletingPathExtension]
                       URLByAppendingPathComponent:@"sqlite-shm"];
    [[NSFileManager defaultManager] removeItemAtURL:storeShm
                                              error:&error];
    DDLogWarn(@"Deleted store shm %@, error: %@", storeShm, error);
    error = nil;
    NSURL *storeWal = [[storeURL URLByDeletingPathExtension]
                       URLByAppendingPathComponent:@"sqlite-wal"];
    [[NSFileManager defaultManager] removeItemAtURL:storeWal
                                              error:&error];
    DDLogWarn(@"Deleted store wal %@, error: %@", storeWal, error);
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:nil
                                                           error:&error]) {
      DDLogError(@"Still got error loading persistent store after deleting: %@, %@", error, error.userInfo);
      abort();
    }
  }
  
  return _persistentStoreCoordinator;
}

- (void)saveContext
{
  NSError *error = nil;
  NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
  if (managedObjectContext != nil) {
    if ([managedObjectContext hasChanges]){
      DDLogInfo(@"DB changes found, saving.");
      if(![managedObjectContext save:&error]) {
        DDLogError(@"Unresolved error while saving %@, %@", error, [error userInfo]);
        abort();
      }
    }
  }
}

- (void)resetStore
{
  DFPhotoCollection *allPhotos = [DFPhotoStore allPhotosCollectionUsingContext:[self managedObjectContext]];
  
  DDLogInfo(@"Reset store requested.  Deleting %lu items.", (unsigned long)allPhotos.photoSet.count);
  for (NSManagedObject *managedObject in allPhotos.photoSet) {
    [_managedObjectContext deleteObject:managedObject];
  }
  [self saveContext];
}

- (void)deletePhotoWithPhotoID:(DFPhotoIDType)photoID
{
  DFPhoto *photo = [self photoWithPhotoID:photoID];
  if (photo) {
    [[self managedObjectContext] deleteObject:photo];
  }
}


#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


- (void)saveImageToCameraRoll:(UIImage *)image
                 withMetadata:(NSDictionary *)metadata
                   completion:(void(^)(NSError *error))completion
{
  NSMutableDictionary *mutableMetadata = metadata.mutableCopy;
  [self addOrientationToMetadata:mutableMetadata forImage:image];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self.assetsLibrary writeImageToSavedPhotosAlbum:image.CGImage
                                            metadata:mutableMetadata
                                     completionBlock:^(NSURL *assetURL, NSError *error) {
                                       completion(error);
                                     }];
  });
}

- (void)addOrientationToMetadata:(NSMutableDictionary *)metadata forImage:(UIImage *)image
{
  metadata[@"Orientation"] = @([image CGImageOrientation]);
}


- (void)fetchMostRecentSavedPhotoDate:(void (^)(NSDate *date))completion
                promptUserIfNecessary:(BOOL)promptUser
{
  if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusAuthorized
      && !promptUser) {
    DDLogVerbose(@"Not authorized to check for last photo date and promptUser false.");
    return;
  }
  
  [self.assetsLibrary
   enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
   usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
     if (group.numberOfAssets > 0) {
       [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:group.numberOfAssets - 1]
                               options:0
                            usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                              if (result) {
                                NSDate *date = [result valueForProperty:ALAssetPropertyDate];
                                completion(date);
                                *stop = YES;
                              }
                            }];
     } else if (group != nil) {
       completion(nil);
     }
  } failureBlock:^(NSError *error) {
    DDLogError(@"%@ couldn't enumerate photos: %@", [self.class description], error.description);
  }];
}


@end



