//
//  DFImageStore.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageStore.h"

#import <FMDB/FMDB.h>
#import "NSString+DFHelpers.h"

#import "DFPhotoMetadataAdapter.h"
#import "DFTypedefs.h"
#import "DFImageDownloadManager.h"
#import "DFPhotoResizer.h"

@interface DFImageStore()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;
@property (nonatomic, retain) NSMutableSet *remoteLoadsInProgress;
@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (nonatomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;

@property (atomic, retain) NSMutableDictionary *idsByImageTypeCache;

@property (nonatomic, readonly, retain) FMDatabase *db;
@property (nonatomic, readonly, retain) FMDatabaseQueue *dbQueue;

@end

@implementation DFImageStore

@synthesize photoAdapter = _photoAdapter;
@synthesize deferredCompletionBlocks = _deferredCompletionBlocks;
@synthesize db = _db;

static DFImageStore *defaultStore;

+ (DFImageStore *)sharedStore {
  if (!defaultStore) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [self createCacheDirectories];
      defaultStore = [[super allocWithZone:nil] init];
    });
  }
  return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedStore];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self initDB];
    _deferredCompletionBlocks = [NSMutableDictionary new];
    self.deferredCompletionSchedulerSemaphore = dispatch_semaphore_create(1);
    self.remoteLoadsInProgress = [[NSMutableSet alloc] init];
    self.idsByImageTypeCache = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                           @(DFImageThumbnail), [NSMutableSet new],
                           @(DFImageFull), [NSMutableSet new],
                           nil];
    [self loadDownloadedImagesCache];
  }
  return self;
}


- (void)initDB
{
  _db = [FMDatabase databaseWithPath:[self.class dbPath]];
  
  if (![_db open]) {
    DDLogError(@"Error opening downloadedImages database.");
    _db = nil;
  }
  if (![_db tableExists:@"downloadedImages"]) {
    [_db executeUpdate:@"CREATE TABLE downloadedImages (image_type NUMBER, photo_id NUMBER)"];
  }
  
  _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[self.class dbPath]];
}

+ (NSString *)dbPath
{
  NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSURL *dbURL = [documentsURL URLByAppendingPathComponent:@"downloaded_images.db"];
  return [dbURL path];
}


- (NSMutableSet *)imageIdsFromDBForType:(DFImageType)type
{
  FMResultSet *results = [self.db executeQuery:@"SELECT photo_id FROM downloadedImages WHERE image_type=(?)", @(type)];
  NSMutableSet *resultIDs = [NSMutableSet new];
  while ([results next]) {
    [resultIDs addObject:@([results longLongIntForColumn:@"photo_id"])];
  }
  return resultIDs;
}

- (void)addToDBImageForType:(DFImageType)type forPhotoID:(DFPhotoIDType)photoID
{
  [self.dbQueue inDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"INSERT INTO downloadedImages VALUES (?, ?)",
     @(type),
     @(photoID)];
    DDLogInfo(@"Saving into downloaded image db: %u %llu", type, photoID);
  }];
}

- (NSMutableSet *)getPhotoIdsForType:(DFImageType)type
{
  return self.idsByImageTypeCache[@(type)];
}

- (void)loadDownloadedImagesCache
{
  NSMutableSet *photoIds = [self imageIdsFromDBForType:DFImageThumbnail];
  [self.idsByImageTypeCache setObject:photoIds forKey:@(DFImageThumbnail)];
  
  photoIds = [self imageIdsFromDBForType:DFImageFull];
  [self.idsByImageTypeCache setObject:photoIds forKey:@(DFImageFull)];
}

- (void)setImage:(UIImage *)image
            type:(DFImageType)type
           forID:(DFPhotoIDType)photoID
      completion:(SetImageCompletion)completion
{
  NSURL *url = [DFImageStore localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *data = UIImageJPEGRepresentation(image, 0.75);
      [data writeToURL:url atomically:YES];
      
      // Record that we've written this file out
      NSMutableSet *photoIds = self.idsByImageTypeCache[@(type)];
      [photoIds addObject:@(photoID)];
      [self addToDBImageForType:type forPhotoID:photoID];
      
      [self executeDeferredCompletionsWithImage:image forPhotoID:photoID];
      
      if (completion) completion(nil);
    }
  });
}

- (void)imageForID:(DFPhotoIDType)photoID
     preferredType:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock
{
  NSURL *localUrl = [DFImageStore localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *imageData = [NSData dataWithContentsOfURL:localUrl];
      if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        completionBlock(image);
      } else {
        DDLogVerbose(@"Didn't find image data for photo %lld, downloading...", photoID);
        [self scheduleDeferredCompletion:completionBlock forPhotoID:photoID];
        [[DFImageDownloadManager sharedManager]
         fetchImageDataForImageType:type
         andPhotoID:photoID
         completion:^(UIImage *image) {
           [self setImage:image type:type forID:photoID completion:nil];
         }];
      }
    }
  });
}

- (void)scheduleDeferredCompletion:(ImageLoadCompletionBlock)completion forPhotoID:(DFPhotoIDType)photoID
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(photoID)];
  if (!deferredForID) {
    deferredForID = [[NSMutableArray alloc] init];
    self.deferredCompletionBlocks[@(photoID)] = deferredForID;
  }
  
  [deferredForID addObject:[completion copy]];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
}

- (void)executeDeferredCompletionsWithImage:(UIImage *)image forPhotoID:(DFPhotoIDType)photoID
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(photoID)];
  for (ImageLoadCompletionBlock completion in deferredForID) {
    completion(image);
  }
  [deferredForID removeAllObjects];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
}


#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

+ (void)createCacheDirectories
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToCreate = @[[[self localThumbnailsDirectoryURL] path],
                                   [[self localFullImagesDirectoryURL] path]];
  
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

#pragma mark - File Paths


+ (NSURL *)localURLForPhotoID:(DFPhotoIDType)photoID type:(DFImageType)type
{
  if (photoID == 0) return nil;
  // if we have an actual photo id, that's used in the path
  NSString *filename;
  filename = [NSString stringWithFormat:@"%llu.jpg", photoID];

  if (type == DFImageFull) {
    return [[DFImageStore localFullImagesDirectoryURL] URLByAppendingPathComponent:filename];
  } else if (type == DFImageThumbnail) {
    return [[DFImageStore localThumbnailsDirectoryURL] URLByAppendingPathComponent:filename];
  }
  
  return nil;
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

+ (NSURL *)localFullImagesDirectoryURL
{
  return [[self userLibraryURL] URLByAppendingPathComponent:@"fullsize"];
}

+ (NSURL *)localThumbnailsDirectoryURL
{
  return [[self userLibraryURL] URLByAppendingPathComponent:@"thumbnails"];
}

- (NSError *)clearCache
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToDeleteAndCreate = @[[[self.class localThumbnailsDirectoryURL] path],
                                   [[self.class localFullImagesDirectoryURL] path]];
  
  // delete the cache directories
  for (NSString *path in directoriesToDeleteAndCreate) {
    if ([fm fileExistsAtPath:path]) {
      NSError *error;
      [fm removeItemAtPath:path error:&error];
      DDLogInfo(@"%@ deleting: %@", self.class, path.lastPathComponent);
      if (error) {
        DDLogError(@"Error deleting cache directory: %@, error: %@", path, error.description);
        return error;
      }
    }
  }

  // clear the DB table
  if ([self.db tableExists:@"downloadedImages"]) {
    DDLogInfo(@"%@ clearing all rows from downloadedImagesTable", self.class);
    [self.db executeUpdate:@"DELETE FROM downloadedImages"];
  }
  
  
  [self.class createCacheDirectories];
  return nil;
}

#pragma mark - Network Adapters

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
    
  }
  return _photoAdapter;
}

- (BOOL)canServeRequest:(DFImageManagerRequest *)request
{
  return [[self imageIdsFromDBForType:[request imageType]] containsObject:@(request.photoID)];
}

- (UIImage *)serveImageForRequest:(DFImageManagerRequest *)request
{
  NSURL *url = [self.class localURLForPhotoID:request.photoID type:request.imageType];
  if (request.isDefaultThumbnail) {
    NSData *imageData = [NSData dataWithContentsOfURL:url];
    if (imageData) {
      UIImage *image = [UIImage imageWithData:imageData];
      return image;
    }
  }
  DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:url];
  if (request.contentMode == DFImageRequestContentModeAspectFit) {
    CGFloat largerDimension = MAX(request.size.width, request.size.height);
    return [resizer aspectImageWithMaxPixelSize:largerDimension];
  } else if (request.contentMode == DFImageRequestContentModeAspectFill) {
    return [resizer aspectFilledImageWithSize:request.size];
  }
  
  return nil;
}

@end
