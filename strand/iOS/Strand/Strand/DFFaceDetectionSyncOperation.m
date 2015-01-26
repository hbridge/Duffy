//
//  DFFaceDetectionSyncOperation.m
//  Strand
//
//  Created by Henry Bridge on 11/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFaceDetectionSyncOperation.h"
#import <ImageIO/ImageIO.h>
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFFaceFeature.h"
#import "DFPeanutPhotoAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFPeanutFaceFeature.h"

@interface DFFaceDetectionSyncOperation()

@property (readonly, nonatomic, retain) NSManagedObjectContext *context;

@end

@implementation DFFaceDetectionSyncOperation

@synthesize context = _context;

// static constant, if we increment this value due to a new scanning technique etc,
// the client will rescan all photos for faces
const int CurrentPassValue = 1;

// max number of photos to scan before saving progress
const NSUInteger PhotosToDetectPerSave = 20;

// max number of photos to scan per pass.  the more photos processed in one pass,
// the longer the queue is blocked to other scanning operations
const NSUInteger PhotosToScanPerOperation = 20;

- (void)main
{
  @autoreleasepool {
    NSDate *startDate = [NSDate date];
    DDLogInfo(@"%@ main beginning.", self.class);
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    [self setupContext];
    
    NSArray *photosToScan = [DFPhotoStore photosWithFaceDetectPassBelow:@(1) inContext:self.context];
    DDLogInfo(@"%@ found %@ photos needingFaceDetection", self.class, @(photosToScan.count));
    
    NSUInteger photosScanned = 0;
    CIDetector *detector = [self.class faceDetectorWithHighQuality:NO];
    for (DFPhoto *photo in photosToScan) {
      [self generateFaceFeaturesWithDetector:detector photo:photo];
      photo.faceDetectPass = @(CurrentPassValue);
      photosScanned++;
      if (photosScanned >= PhotosToDetectPerSave) [self saveContext];
      if (photosScanned >= PhotosToScanPerOperation) break;
      if (self.isCancelled) {
        [self cancelled];
        [self saveContext];
        return;
      }
    }
    
    NSDate *scanEnd = [NSDate date];
    [self patchServerForUnuploadedPhotos];
    
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    [self saveContext];
    DDLogInfo(@"%@ main exit after scanning %@ photos in %.02fs.",
              self.class,
              @(photosScanned),
              [scanEnd timeIntervalSinceDate:startDate]);
  }
}

- (void)setupContext
{
  _context = [DFPhotoStore createBackgroundManagedObjectContext];
  [_context setMergePolicy:[[NSMergePolicy alloc]
                            initWithMergeType:NSMergeByPropertyStoreTrumpMergePolicyType]];
}

- (void)cancelled
{
  DDLogInfo(@"%@ cancelled.  Stopping.", self.class);
}

- (void)saveContext
{
  @try {
    NSError *error;
    if (self.context.hasChanges) {
      [self.context save:&error];
    }
    if (error) {
      DDLogError(@"%@ failed to save context", error);
    }
  }
  @catch (NSException *exception) {
    DDLogError(@"Exception saving context: %@", exception);
  }
}

+ (CIDetector *)faceDetectorWithHighQuality:(BOOL)highQuality
{
  CIContext *context = [CIContext contextWithOptions:nil];
  
  NSDictionary *detectorOpts;
  if (highQuality) {
    detectorOpts = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh };
  } else {
    detectorOpts = @{ CIDetectorAccuracy : CIDetectorAccuracyLow };
  }
  return [CIDetector detectorOfType:CIDetectorTypeFace
                            context:context
                            options:detectorOpts];
}

- (void)generateFaceFeaturesWithDetector:(CIDetector *)detector
                                   photo:(DFPhoto *)photo
{
  @autoreleasepool {
    dispatch_semaphore_t loadSemaphore = dispatch_semaphore_create(0);
    UIImage __block *image = nil;
    [photo.asset loadImageResizedToLength:2048 success:^(UIImage *loadedImage) {
      image = loadedImage;
      dispatch_semaphore_signal(loadSemaphore);
    } failure:^(NSError *error) {
      DDLogError(@"%@ failed to load image: %@", self.class, error);
      dispatch_semaphore_signal(loadSemaphore);
    }];
    dispatch_semaphore_wait(loadSemaphore, DISPATCH_TIME_FOREVER);
    
    if (!image) return;
    CIImage *ciImage = [[CIImage alloc] initWithCGImage:[image CGImage]];
    
    NSMutableDictionary *operationOptions = [[NSMutableDictionary alloc] init];
    if ([ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation]) {
      [operationOptions addEntriesFromDictionary:
       @{ CIDetectorImageOrientation :
            [ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation] }]; // 4
    }
    [operationOptions addEntriesFromDictionary:@{
                                                 CIDetectorSmile: @(YES),
                                                 CIDetectorEyeBlink: @(YES),
                                                 }];
    
    NSArray *CIFaceFeatures = [detector featuresInImage:ciImage options:operationOptions];
    DDLogVerbose(@"Found %@ faceFeatures for photo: %@.", @(CIFaceFeatures.count), @(photo.photoID));
    for (CIFaceFeature *ciFaceFeature in CIFaceFeatures) {
      DFFaceFeature *faceFeature = [DFFaceFeature createWithCIFaceFeature:ciFaceFeature
                                                                inContext:self.context];
      faceFeature.photo = photo;
      DDLogVerbose(@"created DFaceFeature: %@", faceFeature);
    }
  }
}


- (void)patchServerForUnuploadedPhotos
{
  DFPhotoCollection *photosNotUploaded = [DFPhotoStore photosWithFaceDetectPassUploadedBelow:@(CurrentPassValue)
                                                                         inContext:self.context];
  
  
  if (photosNotUploaded.count == 0) return;
  
  NSMutableArray *processedPhotos = [NSMutableArray new];
  NSMutableArray *peanutPhotos = [NSMutableArray new];
  for (DFPhoto *photo in photosNotUploaded.photoSet.allObjects) {
    if (photo.photoID == 0) {
      continue; // if we don't have a photo ID, we can't process the photo
    }
    [processedPhotos addObject:photo];
    if (photo.faceFeatures.count == 0) continue;
    if (photo.faceDetectPass.intValue != CurrentPassValue) continue;
    
    DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] init];
    peanutPhoto.id = @(photo.photoID);
    peanutPhoto.user = @(photo.userID);
    NSArray *peanutFaceFeatures = [[DFPeanutFaceFeature
                                   peanutFaceFeaturesFromDFFaceFeatures:photo.faceFeatures] allObjects];
    [peanutPhoto setIPhoneFaceboxesWithDFPeanutFaceFeatures:peanutFaceFeatures];
    [peanutPhotos addObject:peanutPhoto];
  }
  
  BOOL __block success = NO; // use a bool + semaphore to ensure we write the uploaded bit from the right thread
  if (peanutPhotos.count > 0) {
    dispatch_semaphore_t patchSemaphore = dispatch_semaphore_create(0);
    DFPeanutPhotoAdapter *photoAdapter = [[DFPeanutPhotoAdapter alloc] init];
    [photoAdapter patchPhotos:peanutPhotos success:^(NSArray *resultObjects){
      DDLogInfo(@"%@ uploading face detection results for %@ photos with faces succeeded", self.class, @(resultObjects.count));
      success = YES;
      dispatch_semaphore_signal(patchSemaphore);
    } failure:^(NSError *error){
      DDLogError(@"%@ uploading face detection failed %@", self.class, error.description);
      dispatch_semaphore_signal(patchSemaphore);
    }];
    dispatch_semaphore_wait(patchSemaphore, DISPATCH_TIME_FOREVER);
  } else {
    success = YES; //if we didn't find any photos with face detect data, we should still mark them as uploaded
  }
  
  if (success) {
    for (DFPhoto *photo in processedPhotos) {
      photo.faceDetectPassUploaded = photo.faceDetectPass;
    }
  }
}


@end
