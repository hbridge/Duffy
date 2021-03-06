//
//  DFDataHasher.h
//  Duffy
//
//  Created by Henry Bridge on 4/22/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;

@interface DFDataHasher : NSObject


+ (NSData *)hashDataForALAsset:(ALAsset *)asset;
+ (NSString *)hashStringForHashData:(NSData *)hashData;
+ (NSData *)hashDataForData:(NSData *)inputData;
+ (NSData *)hashDataForData:(NSData *)inputData maxLength:(NSUInteger)maxLength;
+ (NSData *)hashDataForUIImage:(UIImage *)image;

@end
