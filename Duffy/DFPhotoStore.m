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

@interface DFPhotoStore(){
    NSManagedObjectContext *_managedObjectContext;
}

@property (nonatomic, retain) DFPhotoCollection *cameraRoll;
@property (nonatomic, retain) NSMutableDictionary *allDFAlbumsByName;

@end

@implementation DFPhotoStore

@synthesize assetsLibrary = _assetsLibrary;


NSString *const DFPhotoStoreCameraRollUpdated = @"DFPhotoStoreCameraRollUpdated";
NSString *const DFPhotoStoreCameraRollScanComplete = @"DFPhotoStoreCameraRollScanComplete";

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
        [self createCacheDirectories];
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

- (void)createCacheDirectories
{
    // thumbnails
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *directoriesToCreate = @[[[DFPhoto localThumbnailsDirectoryURL] path],
                                     [[DFPhoto localFullImagesDirectoryURL] path]];
    
    for (NSString *path in directoriesToCreate) {
        if (![fm fileExistsAtPath:path]) {
            NSError *error;
            [fm createDirectoryAtPath:path withIntermediateDirectories:NO
                           attributes:nil
                                error:&error];
            if (error) {
                DDLogError(@"Error creating cache directory: %@, error: %@", path, error.description);
                abort();
            }
        }

    }
}

- (void)loadCameraRollDB
{
    self.cameraRoll = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollUpdated object:self];
}

+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
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


+ (DFPhoto *)photoWithALAssetURLString:(NSString *)assetURLString context:(NSManagedObjectContext *)context;
{
    return [[self photosWithALAssetURLStrings:[NSArray arrayWithObject:assetURLString] context:context] firstObject];
}

static int const FetchStride = 500;

+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;
{
    NSMutableArray *allObjects = [[NSMutableArray alloc] init];
    unsigned int numFetched = 0;
    while (numFetched < assetURLStrings.count) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
        request.entity = entity;
        
        NSMutableArray *predicates = [[NSMutableArray alloc] init];
        for (int i = numFetched; i < MIN(numFetched + FetchStride, assetURLStrings.count); i++) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"alAssetURLString ==[c] %@", assetURLStrings[i]];
            [predicates addObject:predicate];
        }
        
        NSPredicate *orPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
        request.predicate = orPredicate;
        
        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];
        if (!result) {
            [NSException raise:@"Could search for photos with ALAssetURLs."
                        format:@"Error: %@", [error localizedDescription]];
        }
        
        [allObjects addObjectsFromArray:result];
        numFetched += predicates.count; // we use the predicates count to avoid getting into an infinite loop
                                        // in case one of the search terms wasn't found in the DB
    }
    
    return allObjects;
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

- (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"photoID == %llu", photoID];
  DFPhotoCollection *results = [DFPhotoStore photosWithPredicate:predicate inContext:[self managedObjectContext]];
  if (results.photoSet.count > 1) {
    [NSException raise:@"Multiple photos matching ID" format:@"%lu photos matching id:%llu",
     (unsigned long)results.photoSet.count, photoID];
  } else if (results.photoSet.count == 0) {
    return nil;
  }
  
  return [[results photosByDateAscending:YES] firstObject];
}

+ (DFPhotoCollection *)photosWithThumbnailUploadStatus:(BOOL)isThumbnailUploaded
                                      fullUploadStatus:(BOOL)isFullPhotoUploaded
                                             inContext:(NSManagedObjectContext *)context;
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    NSPredicate *thumbnailPredicate;
    if (isThumbnailUploaded) {
        thumbnailPredicate = [NSPredicate predicateWithFormat:@"upload157Date != nil"];
    } else {
        thumbnailPredicate = [NSPredicate predicateWithFormat:@"upload157Date = nil"];
    }
    
    NSPredicate *fullPredicate;
    if (isFullPhotoUploaded) {
        fullPredicate = [NSPredicate predicateWithFormat:@"upload569Date != nil"];
    } else {
        fullPredicate = [NSPredicate predicateWithFormat:@"upload569Date = nil"];
    }
    
    NSCompoundPredicate *compoundPredicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                         subpredicates:@[thumbnailPredicate, fullPredicate]];
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


+ (NSURL *)userLibraryURL
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    
    if ([paths count] > 0)
    {
        return [paths objectAtIndex:0];
    }
    return nil;
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

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}




@end



