//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"
#import <AssetsLibrary/ALAsset.h>

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;

@end


@implementation DFPhoto


- (id)initWithAsset:(ALAsset *)asset;
{
    self = [super init];
    if (self) {
        self.asset = asset;
        
    }
    return self;
}


- (UIImage *)thumbnail {
    CGImageRef imageRef = [self.asset thumbnail];
    return [UIImage imageWithCGImage:imageRef];
}


@end
