//
//  DFFaceFeature.h
//  Strand
//
//  Created by Henry Bridge on 11/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DFPhoto;

@interface DFFaceFeature : NSManagedObject

@property (nonatomic, retain) NSValue *bounds;
@property (nonatomic, retain) NSNumber * hasSmile;
@property (nonatomic, retain) NSNumber * hasBlink;
@property (nonatomic, retain) NSNumber * faceRotation;
@property (nonatomic, retain) DFPhoto *photo;

+ (DFFaceFeature *)createWithCIFaceFeature:(CIFaceFeature *)ciFeature
                                 inContext:(NSManagedObjectContext *)context;

@end
