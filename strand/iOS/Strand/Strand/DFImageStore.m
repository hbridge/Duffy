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

@interface DFImageStore()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;
@property (nonatomic, retain) NSMutableSet *remoteLoadsInProgress;
@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (nonatomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;

@property (atomic, retain) NSMutableDictionary *idsByImageTypeCache;

@property (nonatomic, readonly, retain) FMDatabase *db;

@end

@implementation DFImageStore

@synthesize photoAdapter = _photoAdapter;
@synthesize deferredCompletionBlocks = _deferredCompletionBlocks;
@synthesize db = _db;

static DFImageStore *defaultStore;

+ (DFImageStore *)sharedStore {
  if (!defaultStore) {
    [self createCacheDirectories];
    defaultStore = [[super allocWithZone:nil] init];
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


- (FMDatabase *)db
{
  if (!_db) {
    _db = [FMDatabase databaseWithPath:[self.class dbPath]];
    
    if (![_db open]) {
      DDLogError(@"Error opening downloadedImages database.");
      _db = nil;
    }
    if (![_db tableExists:@"downloadedImages"]) {
      [_db executeUpdate:@"CREATE TABLE downloadedImages (image_type NUMBER, photo_id NUMBER)"];
    }
  }
  return _db;
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
  [self.db executeUpdate:@"INSERT INTO downloadedImages VALUES (?, ?)",
   @(type),
   @(photoID)];
  DDLogInfo(@"Saving into downloaded image db: %u %llu", type, photoID);
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
        [[DFImageDownloadManager sharedManager] fetchImageDataForImageType:type andPhotoID:photoID];
      }
    }
  });
}

/*
- (void)imageForID:(DFPhotoIDType)photoID
     preferredType:(DFImageType)preferredType
     thumbnailPath:(NSString *)thumbnailPath
          fullPath:(NSString *)fullPath
        completion:(ImageLoadCompletionBlock)completionBlock
{
  if (![thumbnailPath isNotEmpty] && ![fullPath isNotEmpty]) {
    DDLogWarn(@"%@ imageForID withPaths requested but both paths are empty.", [self.class description]);
    completionBlock(nil);
  }
  
  NSURL *preferredLocalURL = [DFImageStore localURLForPhotoID:photoID type:preferredType];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *imageData = [NSData dataWithContentsOfURL:preferredLocalURL];
      if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        completionBlock(image);
        [self executeDefferredCompletionsWithImage:image forPhotoID:photoID];
      } else {
        [self scheduleDeferredCompletion:completionBlock forPhotoID:photoID];
        if ([self.remoteLoadsInProgress containsObject:@(photoID)]) return;
        
        [self.remoteLoadsInProgress addObject:@(photoID)];
        NSDictionary *imageTypesToPaths;
        if (preferredType & DFImageFull && [fullPath isNotEmpty]) {
          imageTypesToPaths = @{@(DFImageFull) : fullPath};
        } else if ([thumbnailPath isNotEmpty]) {
          imageTypesToPaths = @{@(DFImageThumbnail) : thumbnailPath};
        }
        
        [self.photoAdapter
         getImageDataForTypesWithPaths:imageTypesToPaths
         withCompletionBlock:^(NSDictionary *imageDataDict, NSError *error) {
           UIImage *resultImage;
           DFImageStore __weak *weakSelf = self;
           DFImageType resultType = [(NSNumber *)imageDataDict.allKeys.firstObject intValue];
           NSData *imageData = imageDataDict.allValues.firstObject;
           if (imageData) {
             resultImage = [UIImage imageWithData:imageData];
             [self setImageData:imageData type:resultType forID:photoID completion:^(NSError *error) {
               [weakSelf executeDefferredCompletionsWithImage:resultImage forPhotoID:photoID];
             }];
           } else {
             DDLogWarn(@"%@ image data for %@ nil", [self.class description],
                       imageTypesToPaths.description);
             [weakSelf executeDefferredCompletionsWithImage:resultImage forPhotoID:photoID];
           }
           completionBlock(resultImage);
         }];
      }
    }
  });
}


- (void)remoteLoadForPhotoID:(DFPhotoIDType)photoID
               withLoadBlock:(void(^)(ImageLoadCompletionBlock))loadBlock
             completionBlock:(ImageLoadCompletionBlock)completionBlock
{
  [self scheduleDeferredCompletion:completionBlock forPhotoID:photoID];
   if (![self.remoteLoadsInProgress containsObject:@(photoID)]) {
     [self.remoteLoadsInProgress addObject:@(photoID)];
     loadBlock(^(UIImage *image) {
       completionBlock(image);
       [self executeDeferredCompletionsWithImage:image forPhotoID:photoID];
     });
   }
}
*/

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

+ (NSError *)clearCache
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToDeleteAndCreate = @[[[self localThumbnailsDirectoryURL] path],
                                   [[self localFullImagesDirectoryURL] path]];
  
  for (NSString *path in directoriesToDeleteAndCreate) {
    if ([fm fileExistsAtPath:path]) {
      NSError *error;
      [fm removeItemAtPath:path error:&error];
      if (error) {
        DDLogError(@"Error deleting cache directory: %@, error: %@", path, error.description);
        return error;
      }
    }
  }
  [self createCacheDirectories];
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


@end
