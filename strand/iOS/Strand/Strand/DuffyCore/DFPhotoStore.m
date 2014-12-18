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
#import "DFStrandPhotoAsset.h"
#import "DFCameraRollPhotoAsset.h"
#import "DFSettings.h"
#import "DFUploadController.h"
#import "DFImageDiskCache.h"
#import "AppDelegate.h"

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
    
    //register to hear about other context saves so we can merge in changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundContextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
  }
  return self;
}


+ (NSManagedObjectContext *)createBackgroundManagedObjectContext
{
  NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
  NSPersistentStoreCoordinator *coordinator = [DFPhotoStore persistentStoreCoordinator];
  if (coordinator) {
    managedObjectContext.persistentStoreCoordinator = coordinator;
  } else {
    DDLogWarn(@"%@ persistent createManagedObjectContext store coordinator nil", self);
  }
  return managedObjectContext;
}

+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context
                                              maxCount:(NSUInteger)maxCount
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  request.fetchLimit = maxCount;
  
  NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSSortDescriptor *dateSort = [NSSortDescriptor sortDescriptorWithKey:@"localCreationDate" ascending:YES];
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
                         entityName:(NSString *)entityName
                   comparisonString:(NSString *)comparisonString
                          inContext:(NSManagedObjectContext *)context
{
  NSString *predicateFormat = [NSString stringWithFormat:@"%@ %@ %@",
                               key, comparisonString ? comparisonString : @"=", @"%@"];
  
  NSMutableArray *allObjects = [[NSMutableArray alloc] init];
  unsigned int numFetched = 0;
  while (numFetched < values.count) {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:entityName];
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

+ (NSArray *)photosWithFaceDetectPassBelow:(NSNumber *)faceDetectPass
                                 inContext:(NSManagedObjectContext *)context
{
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"DFPhoto" inManagedObjectContext:context];
  [fetchRequest setEntity:entity];

  NSPredicate *lessThanPredicate = [NSPredicate predicateWithFormat:@"faceDetectPass < %@", faceDetectPass];
  NSPredicate *nilPredicate = [NSPredicate predicateWithFormat:@"faceDetectPass = nil"];
  NSPredicate *uploadLessThanPredicate = [NSPredicate predicateWithFormat:@"faceDetectPassUploaded < %@", faceDetectPass];
  NSPredicate *uploadNilPredicate = [NSPredicate predicateWithFormat:@"faceDetectPassUploaded = nil"];
  
  
  NSCompoundPredicate *predicate = [NSCompoundPredicate
                                    orPredicateWithSubpredicates:@[lessThanPredicate,
                                                                   nilPredicate,
                                                                   uploadLessThanPredicate,
                                                                   uploadNilPredicate]];
  [fetchRequest setPredicate:predicate];
  
  NSError *error = nil;
  NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
  if (fetchedObjects == nil) {
    DDLogError(@"%@ error fetching photosWithFaceDetectionPassBelow: %@", self, error);
  }
  return fetchedObjects;
}


+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;
{
  NSArray *photoAssets = [self photosWithValueStrings:assetURLStrings
                               forKey:@"alAssetURLString"
                          entityName:@"DFCameraRollPhotoAsset"
                     comparisonString:@"==[c]"
                            inContext:context];
  NSMutableArray *photos = [NSMutableArray new];
  for (DFCameraRollPhotoAsset *asset in photoAssets)
  {
    if (asset.isDeleted) continue;
    if (!asset.photo) continue;
    [photos addObject:asset.photo];
  }
 
  return photos;
}

+ (NSArray *)photosWithPHAssetIdentifiers:(NSArray *)assetIds context:(NSManagedObjectContext *)context;
{
  NSArray *photoAssets = [self photosWithValueStrings:assetIds
                                               forKey:@"localIdentifier"
                                           entityName:@"DFPHAsset"
                                     comparisonString:@"==[c]"
                                            inContext:context];
  NSMutableArray *photos = [NSMutableArray new];
  for (DFCameraRollPhotoAsset *asset in photoAssets)
  {
    [photos addObject:asset.photo];
  }
  
  return photos;
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

+ (NSArray *)photosWithoutPhotoIDInContext:(NSManagedObjectContext *)context
{
  return [self photosWithValueStrings:@[@(0)]
                                           forKey:@"photoID"
                                       entityName:@"DFPhoto"
                                 comparisonString:@"="
                                        inContext:context];
}

+ (NSDictionary *)photosWithPhotoIDs:(NSArray *)photoIDs
                      inContext:(NSManagedObjectContext *)context
{
  NSArray *results = [self photosWithValueStrings:photoIDs
                                           forKey:@"photoID"
                                       entityName:@"DFPhoto"
                                 comparisonString:@"="
                                        inContext:context];
  NSMutableDictionary *photoIDsToPhotos = [[NSMutableDictionary alloc] init];
  for (DFPhoto *photo in results) {
    photoIDsToPhotos[@(photo.photoID)] = photo;
  }
  
  return photoIDsToPhotos;
}

- (NSDictionary *)photosWithPhotoIDs:(NSArray *)photoIDs
{
  return [DFPhotoStore photosWithPhotoIDs:photoIDs
                                inContext:[self managedObjectContext]];
}

+ (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID inContext:(NSManagedObjectContext *)context
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"photoID == %llu", photoID];
  DFPhotoCollection *results = [DFPhotoStore photosWithPredicate:predicate inContext:context];
  if (results.photoSet.count > 1) {
    DDLogWarn(@"Multiple photos matching ID: %llu photos matching id:%lu",
              photoID, (unsigned long)results.photoSet.count);
              //[NSException raise:@"Multiple photos matching ID" format:@"%lu photos matching id:%llu",
    //(unsigned long)results.photoSet.count, photoID];
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
  request.predicate = [NSPredicate predicateWithFormat:@"uploadThumbDate != nil"];
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

- (DFPhotoCollection *)photosWithUploadProcessedStatus:(BOOL)processedStatus
                                     shouldUploadImage:(BOOL)shouldUploadImage
{
  NSPredicate *processedPredicate;
  if (processedStatus) {
    processedPredicate = [NSPredicate predicateWithFormat:@"isUploadProcessed == YES"];
  } else {
    processedPredicate = [NSPredicate predicateWithFormat:@"isUploadProcessed == NO || isUploadProcessed == nil"];
  }
  
  NSPredicate *shouldUploadPredicate;
  if (shouldUploadImage) {
    shouldUploadPredicate = [NSPredicate predicateWithFormat:@"shouldUploadImage == YES"];
  } else {
    shouldUploadPredicate = [NSPredicate predicateWithFormat:@"shouldUploadImage == NO || shouldUploadImage = nil"];
  }

  NSCompoundPredicate *compoundPredicate = [[NSCompoundPredicate alloc]
                                            initWithType:NSAndPredicateType
                                            subpredicates:@[processedPredicate, shouldUploadPredicate]];
  
  return  [self.class photosWithPredicate:compoundPredicate inContext:[self managedObjectContext]];
}

+ (DFPhotoCollection *)photosWithThumbnailUploadStatus:(DFUploadStatus)thumbnailStatus
                                      fullUploadStatus:(DFUploadStatus)fullStatus
                                     shouldUploadPhoto:(BOOL)shouldUploadPhoto
                                       photoIDRequired:(BOOL)photoIDRequired
                                             inContext:(NSManagedObjectContext *)context;
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
  request.entity = entity;
  
  NSPredicate *thumbnailPredicate;
  if (thumbnailStatus == DFUploadStatusUploaded) {
    thumbnailPredicate = [NSPredicate predicateWithFormat:@"uploadThumbDate != nil"];
  } else if (thumbnailStatus == DFUploadStatusNotUploaded){
    thumbnailPredicate = [NSPredicate predicateWithFormat:@"uploadThumbDate = nil"];
  }
  
  NSPredicate *fullPredicate;
  if (fullStatus == DFUploadStatusUploaded) {
    fullPredicate = [NSPredicate predicateWithFormat:@"uploadLargeDate != nil"];
  } else if (fullStatus == DFUploadStatusNotUploaded) {
    fullPredicate = [NSPredicate predicateWithFormat:@"uploadLargeDate = nil"];
  }
  
  NSPredicate *shouldUploadPredicate;
  if (shouldUploadPhoto) {
    shouldUploadPredicate = [NSPredicate predicateWithFormat:@"shouldUploadImage == YES"];
  } else {
    shouldUploadPredicate = [NSPredicate predicateWithFormat:@"shouldUploadImage == NO || shouldUploadPhoto == nil"];
  }
  
  NSPredicate *photoIDRequiredPredicate;
  if (photoIDRequired) {
    photoIDRequiredPredicate = [NSPredicate predicateWithFormat:@"photoID != 0 && photoID != nil"];
  }
  
  assert(thumbnailPredicate || fullPredicate);
  
  NSMutableArray *subpredicates = [NSMutableArray new];
  if (thumbnailPredicate) [subpredicates addObject:thumbnailPredicate];
  if (fullPredicate) [subpredicates addObject:fullPredicate];
  if (shouldUploadPredicate) [subpredicates addObject:shouldUploadPredicate];
  if (photoIDRequiredPredicate) [subpredicates addObject:photoIDRequiredPredicate];
  NSCompoundPredicate *compoundPredicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                       subpredicates:subpredicates];
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
    predicate = [NSPredicate predicateWithFormat:@"uploadLargeDate != nil"];
  } else {
    predicate = [NSPredicate predicateWithFormat:@"uploadLargeDate = nil"];
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
  
  // merge in the changes to the main context
  // but only if the persistent stores are the same
  NSManagedObjectContext *otherContext = notification.object;
  if (otherContext.persistentStoreCoordinator == self.managedObjectContext.persistentStoreCoordinator) {
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
  }
}

- (void)photosChanged:(NSNotification *)note
{
  
}

- (void)clearUploadInfo
{
  DFPhotoCollection *allPhotosCollection = [DFPhotoStore allPhotosCollectionUsingContext:[self managedObjectContext]];
  for (DFPhoto *photo in allPhotosCollection.photoSet) {
    photo.uploadThumbDate = nil;
    photo.uploadLargeDate = nil;
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
  
  _managedObjectContext = [self.class createBackgroundManagedObjectContext];
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
  
  NSError *error = nil;
  _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                 initWithManagedObjectModel:[self managedObjectModel]];
  if (![_persistentStoreCoordinator
        addPersistentStoreWithType:NSSQLiteStoreType
        configuration:nil
        URL:[self storeURL]
        options: @{
                   NSMigratePersistentStoresAutomaticallyOption:@YES,
                   }
        error:&error]) {
    
    DDLogError(@"%@ error loading persistent store %@, %@", self, error, [error userInfo]);
    [self deleteLocalDB];
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] resetApplication];
  }
  
  return _persistentStoreCoordinator;
}

+ (void)deleteLocalDB
{
  NSURL *storeURL = [self.class storeURL];
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error];
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

+ (void)resetStore
{
  NSManagedObjectContext *context = [self createBackgroundManagedObjectContext];
  DFPhotoCollection *allPhotos = [DFPhotoStore allPhotosCollectionUsingContext:context];
  
  DDLogInfo(@"Reset store requested.  Deleting %lu items.", (unsigned long)allPhotos.photoSet.count);
  for (NSManagedObject *managedObject in allPhotos.photoSet) {
    [context deleteObject:managedObject];
  }
  
  context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
  NSError *error;
  @try {
    [context save:&error];
    if (error) {
      DDLogError(@"%@ error resetting store: %@", self, error);
    }
  } @catch (NSException *exception) {
    DDLogError(@"%@ exception saving store during reset store: %@", self, exception);
        [self deleteLocalDB];
    _persistentStoreCoordinator = nil;
  }
}

- (void)deletePhotoWithPhotoID:(DFPhotoIDType)photoID
{
  DFPhoto *photo = [self photoWithPhotoID:photoID];
  if (photo) {
    [[self managedObjectContext] deleteObject:photo];
    [self saveContext];
  }
}

#pragma mark - Application's Documents directory

+ (NSURL *) storeURL
{
  return [[DFPhotoStore applicationDocumentsDirectory] URLByAppendingPathComponent:@"Duffy.sqlite"];
}

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

/*
 * Add image to a custom photo album
 * Iterates through all the users's groups looking for the correct album, if it doesn't exist, it gets created.
 */
- (void) addAssetWithURL:(NSURL *) assetURL toPhotoAlbum:(NSString *) albumName
{
  [self.assetsLibrary assetForURL:assetURL
                      resultBlock:^(ALAsset *asset)
   {
     __block BOOL found = NO;
     [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop)
      {
        NSString *groupName = [group valueForProperty:ALAssetsGroupPropertyName];
        if ([albumName isEqualToString:groupName])
        {
          [group addAsset:asset];
          found = YES;
        }
      } failureBlock:^(NSError *error)
      {
        DDLogError(@"Error looping over albums: %@, %@", error, error.userInfo);
      }];
     
     if (!found) {
       [self.assetsLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group){
         [group addAsset:asset];
       } failureBlock:^(NSError *error) {
        DDLogError(@"Error creating custom Strand album: %@, %@", error, error.userInfo);
       }];
     }
     
   } failureBlock:^(NSError *error)
   {
   }];
}

- (void)saveImageToCameraRoll:(UIImage *)image
                 withMetadata:(NSDictionary *)metadata
                   completion:(void(^)(NSURL *assetURL, NSError *error))completion
{
  NSMutableDictionary *mutableMetadata = metadata.mutableCopy;
  [self addOrientationToMetadata:mutableMetadata forImage:image];
  
  DDLogVerbose(@"Saving image with metadata: %@", mutableMetadata);
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self.assetsLibrary writeImageToSavedPhotosAlbum:image.CGImage
                                            metadata:mutableMetadata
                                     completionBlock:^(NSURL *assetURL, NSError *error) {
                                       if (error) {
                                         DDLogError(@"%@ couldn't save photo to Camera Roll:%@",
                                                    [self.class description],
                                                    error.description);
                                       } else {
                                         [self addAssetWithURL:assetURL toPhotoAlbum:DFPhotosSaveLocationName];
                                       }
                                       completion(assetURL, error);
                                     }];
  });
}

- (void)addOrientationToMetadata:(NSMutableDictionary *)metadata forImage:(UIImage *)image
{
  metadata[@"Orientation"] = @([image CGImageOrientation]);
}


+ (void)fetchMostRecentSavedPhotoDate:(void (^)(NSDate *date))completion
                promptUserIfNecessary:(BOOL)promptUser
{
  DDLogWarn(@"WARNING: %@ fetchMostRecentSavedPhotoDate should be rewritten.", self);
  if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusAuthorized
      && !promptUser) {
    DDLogVerbose(@"Not authorized to check for last photo date and promptUser false.");
    completion(nil);
    return;
  }
 
  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  [library
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



- (void)markPhotosForUpload:(NSArray *)photoIDs
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSDictionary *photos = [[DFPhotoStore sharedStore] photosWithPhotoIDs:photoIDs];
    for (DFPhoto *photo in photos.allValues) {
      photo.shouldUploadImage = YES;
    }
    [[DFPhotoStore sharedStore] saveContext];
    [[DFUploadController sharedUploadController] uploadPhotos];
  });
}

- (void)cachePhotoIDsInImageStore:(NSArray *)photoIDs
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
      NSDictionary *photos = [DFPhotoStore photosWithPhotoIDs:photoIDs inContext:context];
      for (DFPhoto *photo in photos.allValues) {
        DFPhotoIDType photoID = photo.photoID;
        [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
          [[DFImageDiskCache sharedStore]
           setImage:image
           type:DFImageThumbnail
           forID:photoID
           completion:^(NSError *error) {
             if (!error)
               DDLogVerbose(@"%@ successfully cached thumnbnail for photo id %@", self.class, @(photoID));
             else
               DDLogError(@"%@ failed code 1A to cache thumbnail for photo id %@.  error: %@", self.class, @(photoID), error);
           }];
        } failureBlock:^(NSError *error) {
          DDLogError(@"%@ failed code 1B to cache thumbnail for photo id %@.  error: %@", self.class, @(photoID), error);
        }];
        [photo.asset loadHighResImage:^(UIImage *image) {
          [[DFImageDiskCache sharedStore]
           setImage:image
           type:DFImageFull
           forID:photoID
           completion:^(NSError *error) {
             if (!error)
               DDLogVerbose(@"%@ successfully cached full image for photo id %@", self.class, @(photoID));
             else
               DDLogError(@"%@ failed code 2A to cache full image for photo id %@. error: %@", self.class, @(photoID), error);
             
           }];
        } failureBlock:^(NSError *error) {
          DDLogError(@"%@ failed code 2B to cache full image for photo id %@. error: %@", self.class, @(photoID), error);
        }];
      }
    }
  });
}


@end



