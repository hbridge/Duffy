//
//  DFCameraRollPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DFPhotoAsset.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface DFCameraRollPhotoAsset : DFPhotoAsset <DFPhotoAsset>

@property (nonatomic, retain) NSString * alAssetURLString;

+ (DFCameraRollPhotoAsset *)createWithALAsset:(ALAsset *)asset
                                    inContext:(NSManagedObjectContext *)managedObjectContext;

@end
