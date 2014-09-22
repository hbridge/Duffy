//
//  DFPHAsset.h
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"

@class PHAsset;

@interface DFPHAsset : DFPhotoAsset

@property (nonatomic, retain) NSString * localIdentifier;


+ (DFPHAsset *)createWithPHAsset:(PHAsset *)asset
                       inContext:(NSManagedObjectContext *)managedObjectContext;
+ (NSURL *)URLForPHAsset:(PHAsset *)asset;
+ (NSString *)localIdentifierFromURL:(NSURL *)url;

@end
