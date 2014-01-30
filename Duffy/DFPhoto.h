//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;

@interface DFPhoto : NSObject

- (id)initWithAsset:(ALAsset *)asset;

- (UIImage *)thumbnail;


@end
