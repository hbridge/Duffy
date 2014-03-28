//
//  DFPhoto+FaceDetection.h
//  Duffy
//
//  Created by Henry Bridge on 3/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"

@interface DFPhoto (FaceDetection)

// array of CIFaceFeatures

typedef void (^DFPhotoFaceDetectSuccessBlock)(NSArray *features);

- (void)faceFeaturesInPhoto:(DFPhotoFaceDetectSuccessBlock)successBlock;



@end
