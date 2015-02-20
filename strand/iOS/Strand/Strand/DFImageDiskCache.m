//
//  DFImageStore.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageDiskCache.h"

#import <FMDB/FMDB.h>
#import "DFTypedefs.h"
#import "DFImageDownloadManager.h"
#import "DFPhotoResizer.h"
#import "DFImageManager.h"

@interface DFImageDiskCache()

@property (nonatomic, readonly, retain) FMDatabase *db;
@property (nonatomic, readonly, retain) FMDatabaseQueue *dbQueue;
@property (atomic, retain) NSMutableDictionary *idsByImageTypeCache;

@end

@implementation DFImageDiskCache

@synthesize db = _db;

static DFImageDiskCache *defaultStore;

+ (DFImageDiskCache *)sharedStore {
  if (!defaultStore) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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
    [DFImageDiskCache createCacheDirectories];
    [self initDB];
    [self loadDownloadedImagesCache];
    [self integrityCheck];
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

- (BOOL)haveAlreadyDownloadedPhotoID:(DFPhotoIDType)photoID forType:(DFImageType)type
{
  NSSet *ids = [self imageIdsFromDBForType:type];
  return [ids containsObject:@(photoID)];
}

- (void)addToDBImageForType:(DFImageType)type forPhotoID:(DFPhotoIDType)photoID
{
  [self.dbQueue inDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"INSERT INTO downloadedImages VALUES (?, ?)",
     @(type),
     @(photoID)];
    DDLogInfo(@"Saving into downloaded image db: %@ %llu", type == DFImageFull ? @"full" : @"thumbnail", photoID);
  }];
}

- (NSMutableSet *)getPhotoIdsForType:(DFImageType)type
{
  return self.idsByImageTypeCache[@(type)];
}

- (void)loadDownloadedImagesCache
{
  _idsByImageTypeCache = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          @(DFImageThumbnail), [NSMutableSet new],
                          @(DFImageFull), [NSMutableSet new],
                          nil];

  NSMutableSet *photoIds = [self imageIdsFromDBForType:DFImageThumbnail];
  [self.idsByImageTypeCache setObject:photoIds forKey:@(DFImageThumbnail)];
  
  photoIds = [self imageIdsFromDBForType:DFImageFull];
  [self.idsByImageTypeCache setObject:photoIds forKey:@(DFImageFull)];
}

- (void)integrityCheck
{
  NSError *error;
  NSArray *thumnbailFiles = [[NSFileManager defaultManager]
                             contentsOfDirectoryAtURL:[DFImageDiskCache localThumbnailsDirectoryURL]
                             includingPropertiesForKeys:nil
                             options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                             error:&error];
  NSArray *fullFiles = [[NSFileManager defaultManager]
                        contentsOfDirectoryAtURL:[DFImageDiskCache localFullImagesDirectoryURL]
                        includingPropertiesForKeys:nil
                        options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                        error:&error];
  NSSet *thumbnailsInDB = self.idsByImageTypeCache[@(DFImageThumbnail)];
  NSSet *fullsInDB = self.idsByImageTypeCache[@(DFImageFull)];
  
  DDLogInfo(@"%@ thumbnailFiles: %@ thumbnailsInDB: %@ fullFiles: %@ fulsInDB: %@",
            self.class, @(thumnbailFiles.count), @(thumbnailsInDB.count), @(fullFiles.count), @(fullsInDB.count));
  
  if (thumbnailsInDB.count != thumnbailFiles.count
      || fullsInDB.count != fullFiles.count) {
    DDLogWarn(@"%@ count mismatch. Clearing disk cache.", self.class);
    [self clearCache];
  }
  
}

- (void)setImage:(UIImage *)image
            type:(DFImageType)type
           forID:(DFPhotoIDType)photoID
      completion:(SetImageCompletion)completion
{
  NSURL *url = [DFImageDiskCache localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      BOOL writeSuccessful = NO;
      NSData *data = UIImageJPEGRepresentation(image, 0.75);
      if (data) {
        writeSuccessful = [data writeToURL:url atomically:YES];
      }
      
      if (writeSuccessful) {
        // Record that we've written this file out
        NSMutableSet *photoIds = self.idsByImageTypeCache[@(type)];
        [photoIds addObject:@(photoID)];
        [self addToDBImageForType:type forPhotoID:photoID];
        if (completion) completion(nil);
      } else {
        NSString *description = [NSString stringWithFormat:@"%@ writing %@ bytes failed.",
                                       self.class,
                                       @(data.length)];
        if (completion) completion([NSError errorWithDomain:@"com.duffyapp.strand"
                                                       code:-1030
                                                   userInfo:@{NSLocalizedDescriptionKey : description}]);
      }
    }
  });
}

- (void)imageForID:(DFPhotoIDType)photoID
     preferredType:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock
{
  NSURL *localUrl = [DFImageDiskCache localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *imageData = [NSData dataWithContentsOfURL:localUrl];
      if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        completionBlock(image);
      } else {
        completionBlock(nil);
      }
    }
  });
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
    return [[DFImageDiskCache localFullImagesDirectoryURL] URLByAppendingPathComponent:filename];
  } else if (type == DFImageThumbnail) {
    return [[DFImageDiskCache localThumbnailsDirectoryURL] URLByAppendingPathComponent:filename];
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
  [self loadDownloadedImagesCache];
  [[DFImageManager sharedManager] clearCache];
  
  return nil;
}

#pragma mark - Image Manager Request Servicing


- (BOOL)canServeRequest:(DFImageManagerRequest *)request
{
  NSSet *imageIDsForType = [self getPhotoIdsForType:[request imageType]];
  return [imageIDsForType containsObject:@(request.photoID)];
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

- (UIImage *)fullImageForPhotoID:(DFPhotoIDType)photoID
{
  NSURL *url = [self.class localURLForPhotoID:photoID type:DFImageFull];
  NSData *imageData = [NSData dataWithContentsOfURL:url];
  return [UIImage imageWithData:imageData];
}

@end
