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

@interface DFPhotoStore()

@property (nonatomic, retain) DFPhotoCollection *cameraRoll;
@property (nonatomic, retain) NSMutableDictionary *allDFAlbumsByName;

// background
@property (nonatomic, retain) NSManagedObjectContext *backgroundManagedObjectContext;
@property (nonatomic) dispatch_queue_t backgroundQueue;
@property (atomic) BOOL isCameraRollLoadRequested;


@end

@implementation DFPhotoStore

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
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
        
        // scan camera roll
        self.backgroundQueue = dispatch_queue_create("com.duffysoft.DFPhotoStore.backgroundQueue", DISPATCH_QUEUE_SERIAL);
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
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    NSSortDescriptor *dateSort = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO];
    request.sortDescriptors = [NSArray arrayWithObject:dateSort];
    
    NSError *error;
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
    if (!result) {
        [NSException raise:@"Could not fetch photos"
                    format:@"Error: %@", [error localizedDescription]];
    }
    
    [self.cameraRoll addPhotos:result];
    [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollUpdated object:self];
}

- (void)scanCameraRollForChanges
{
    int __block newAssets = 0;
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
        if(photoAsset != NULL) {
            //TODO should also look for items in DB that have been desleted
            
            
            //NSLog(@"Scanning Camera Roll asset: %@...", result);
            NSURL *assetURL = [photoAsset valueForProperty: ALAssetPropertyAssetURL];
            if (![[self cameraRoll] containsPhotoWithAssetURL:assetURL.absoluteString])
            {
                //NSLog(@"...asset is new, adding to database.");
                // we haven't seent this photo before, add it to our database
                // have to add on main thread, since CoreData is not thread safe
                DFPhoto *newPhoto = [NSEntityDescription
                                     insertNewObjectForEntityForName:@"DFPhoto"
                                     inManagedObjectContext:self.backgroundManagedObjectContext];
                newPhoto.alAssetURLString = assetURL.absoluteString;
                newPhoto.creationDate = [photoAsset valueForProperty:ALAssetPropertyDate];
                newAssets++;
                
                // save to the store so that the main thread context can pick it up
                NSError *error = nil;
                if(![self.backgroundManagedObjectContext save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    [NSException raise:@"Could not save new photo object." format:@"Error: %@",[error localizedDescription]];
                }
                
            } else {
                //NSLog(@"...asset is not new.");
            }
        } else {
            NSLog(@"All assets in Camera Roll enumerated, %d new assets.", newAssets);
            [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollScanComplete object:self];
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            // only want photos for now
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            NSLog(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
    	}
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                          usingBlock:assetGroupEnumerator
                                        failureBlock: ^(NSError *error) {
                                            NSLog(@"Failure");
                                        }];

    });
}


- (DFPhoto *)photoWithALAssetURL:(NSURL *)url context:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[self managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
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

- (NSArray *)photosWithUploadStatus:(BOOL)isUploaded
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[self managedObjectModel] entitiesByName] objectForKey:@"DFPhoto"];
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
    
    return result;
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

#pragma mark - Assets Library

- (ALAssetsLibrary *)assetsLibrary
{
    if (_assetsLibrary == nil) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    return _assetsLibrary;
}



#pragma mark - Core Data stack


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
    [self loadCameraRollDB];
    
}


// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// background context, used for
- (NSManagedObjectContext *)backgroundManagedObjectContext
{
    if (_backgroundManagedObjectContext != nil) {
        return _backgroundManagedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _backgroundManagedObjectContext = [[NSManagedObjectContext alloc] init];
        [_backgroundManagedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    
    // setup stuff for background
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundContextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:_backgroundManagedObjectContext];
    
    return _backgroundManagedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
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
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Duffy.sqlite"];
    
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
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


@end



