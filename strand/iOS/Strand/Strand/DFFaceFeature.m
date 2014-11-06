//
//  DFFaceFeature.m
//  Strand
//
//  Created by Henry Bridge on 11/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFaceFeature.h"
#import "DFPhoto.h"


@implementation DFFaceFeature

@dynamic bounds;
@dynamic hasSmile;
@dynamic hasBlink;
@dynamic faceRotation;
@dynamic photo;

+ (DFFaceFeature *)createWithCIFaceFeature:(CIFaceFeature *)ciFeature
                                 inContext:(NSManagedObjectContext *)context
{
  DFFaceFeature *faceFeature = [NSEntityDescription
                          insertNewObjectForEntityForName:NSStringFromClass([self class])
                          inManagedObjectContext:context];
  
  faceFeature.bounds = [NSValue valueWithCGRect:ciFeature.bounds];
  faceFeature.hasSmile = @(ciFeature.hasSmile);
  faceFeature.hasBlink = @(ciFeature.leftEyeClosed && ciFeature.rightEyeClosed);
  if (ciFeature.hasFaceAngle) {
    faceFeature.faceRotation = @(ciFeature.faceAngle);
  }
  
  return faceFeature;
}


@end
