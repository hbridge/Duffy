//
//  DFPhoto+FaceDetection.h
//  Duffy
//
//  Created by Henry Bridge on 3/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"
#import "DFFaceFeature.h"

@interface DFPhoto (FaceDetection)

// array of CIFaceFeatures

typedef void (^DFPhotoFaceDetectSuccessBlock)(NSArray *features);

+ (CIDetector *)faceDetectorWithHighQuality:(BOOL)highQuality;
- (void)generateFaceFeaturesWithDetector:(CIDetector *)detector isHighQuality:(BOOL)isHighQuality;


@end
