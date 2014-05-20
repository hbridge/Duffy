//
//  DFPhoto+FaceDetection.m
//  Duffy
//
//  Created by Henry Bridge on 3/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto+FaceDetection.h"
#import <ImageIO/ImageIO.h>

@implementation DFPhoto (FaceDetection)


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

- (void)generateFaceFeaturesWithDetector:(CIDetector *)detector isHighQuality:(BOOL)isHighQuality
{
  @autoreleasepool {
    UIImage *scaledRotatedImage = [self highResolutionImage];
    
    CIImage *ciImage = [[CIImage alloc] initWithCGImage:[scaledRotatedImage CGImage]];
    
    
    
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
    DDLogVerbose(@"Found %lu faceFeatures for photo.", (unsigned long)CIFaceFeatures.count);
    [self createFaceFeaturesFromCIFeatures:CIFaceFeatures];
    
    if (isHighQuality) {
      self.faceFeatureSources |= DFFaceFeatureDetectioniOSHighQuality;
    } else {
      self.faceFeatureSources |= DFFaceFeatureDetectioniOSLowQuality;
    }
  }
}

- (void)createFaceFeaturesFromCIFeatures:(NSArray *)CIFaceFeatures
{
  for (CIFaceFeature *CIFaceFeature in CIFaceFeatures) {
    DFFaceFeature *faceFeature =
    [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([DFFaceFeature class])
                                  inManagedObjectContext:self.managedObjectContext];
    faceFeature.boundsString = NSStringFromCGRect(CIFaceFeature.bounds);
    faceFeature.hasSmile = faceFeature.hasSmile;
    faceFeature.hasBlink = faceFeature.hasBlink;
    faceFeature.photo = self;
  }
}

@end
