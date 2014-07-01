//
//  DFPhotoResizer.h
//  Strand
//
//  Created by Henry Bridge on 7/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;

@interface DFPhotoResizer : NSObject

- (id)initWithALAsset:(ALAsset *)asset;
- (id)initWithURL:(NSURL *)imageURL;
- (UIImage *)aspectImageWithMaxPixelSize:(NSUInteger)size;


@end
