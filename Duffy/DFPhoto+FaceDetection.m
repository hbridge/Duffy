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

- (void)faceFeaturesInPhoto:(DFPhotoFaceDetectSuccessBlock)successBlock
{
    UIImage *fullImage = self.fullImage;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        UIGraphicsBeginImageContext(fullImage.size);
        [fullImage drawInRect:CGRectMake(0.0, 0.0, fullImage.size.width, fullImage.size.height)];
        UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        CIImage *ciImage = [[CIImage alloc] initWithCGImage:[rotatedImage CGImage]];
        
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
        
        successBlock([detector featuresInImage:ciImage options:opts]);
    });
}


@end
