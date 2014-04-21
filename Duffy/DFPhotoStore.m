//
//  DFPhotoStore.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStore.h"
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
                NSLog(@"Error creating cache directory: %@, error: %@", path, error.description);
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


- (DFPhoto *)photoWithALAssetURL:(NSURL *)url context:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"alAssetURLString ==[c] %@", url.absoluteString];

    request.predicate = predicate;
    
    NSError *error;
    NSArray *result = [context executeFetchRequest:request error:&error];
    if (!result) {
        [NSException raise:@"Could search for photos."
                    format:@"Error: %@", [error localizedDescription]];
    }
    
    return [result firstObject];
}

- (DFPhotoCollection *)photosWithUploadStatus:(BOOL)isUploaded
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[DFPhotoStore managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    NSPredicate *predicate;
    if (isUploaded) {
        predicate = [NSPredicate predicateWithFormat:@"uploadDate != nil"];
    } else {
         predicate = [NSPredicate predicateWithFormat:@"uploadDate = nil"];
    }
    
    request.predicate = predicate;
    
    NSError *error;
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
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
            NSLog(@"Error fetching photos with IDs: %@", error.localizedDescription);
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
            NSLog(@"DFPhotoStore: notification indicates photo added or removed.  reloading camera roll");
            [self loadCameraRollDB];
            *stop = YES;
        }
    }];
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
                                                         options:@{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
                                                           error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges]){
            NSLog(@"DB changes found, saving.");
            if(![managedObjectContext save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
    }
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}




@end



