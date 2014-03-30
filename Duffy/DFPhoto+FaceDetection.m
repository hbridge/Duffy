//
//  DFPhoto+FaceDetection.m
//  Duffy
//
//  Created by Henry Bridge on 3/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto+FaceDetection.h"
#import <ImageIO/ImageIO.h>
#import "UIImage+Resize.h"

@implementation DFPhoto (FaceDetection)

- (void)faceFeaturesInPhoto:(DFPhotoFaceDetectSuccessBlock)successBlock
{
    UIImage *fullImage = self.fullScreenImage;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSArray *featuresInImage;
        
        @autoreleasepool {
            UIImage *scaledRotatedImage = [fullImage resizedImage:fullImage.size interpolationQuality:kCGInterpolationDefault];
            
            CIImage *ciImage = [[CIImage alloc] initWithCGImage:[scaledRotatedImage CGImage]];
            
            CIContext *context = [CIContext contextWithOptions:nil];
            NSDictionary *opts = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh };
            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                                      context:context
                                                      options:opts];
            
            if ([ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation]) {
                opts = @{ CIDetectorImageOrientation : [ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation] }; // 4
            } else {
                opts = @{};
            }
            
            featuresInImage = [detector featuresInImage:ciImage options:opts];
        }
        successBlock(featuresInImage);
    });
}


@end
