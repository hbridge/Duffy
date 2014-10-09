//
//  DFDataHasher.m
//  Duffy
//
//  Created by Henry Bridge on 4/22/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFDataHasher.h"
#import <CommonCrypto/CommonDigest.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>

@implementation DFDataHasher

const float HasherImageJPEGQuality = 0.8;

// Use the first 20k of bytes to generate the hash
const int DefaultMaxNumHashBytes = 20000;

+ (NSData *)hashDataForData:(NSData *)inputData maxLength:(NSUInteger)maxLength
{
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  
  CC_LONG len = inputData.length > (CC_LONG)maxLength ? (CC_LONG)maxLength : (CC_LONG)inputData.length;
  CC_SHA1(inputData.bytes, len, digest);
  
  return [NSData dataWithBytes:&digest length:CC_SHA1_DIGEST_LENGTH];
}

+ (NSData *)hashDataForData:(NSData *)inputData
{
  return [self hashDataForData:inputData maxLength:DefaultMaxNumHashBytes];
}


+ (NSData *)hashDataForUIImage:(UIImage *)image
{
  return [DFDataHasher hashDataForData:[self JPEGDataForCGImage:image.CGImage withQuality:HasherImageJPEGQuality]];
}

+ (NSData *)hashDataForALAsset:(ALAsset *)asset
{
  return [DFDataHasher hashDataForData:[DFDataHasher JPEGDataForCGImage:asset.thumbnail withQuality:HasherImageJPEGQuality]];
}

+ (NSString *)hashStringForHashData:(NSData *)hashData
{
    uint8_t bytes[hashData.length];
    [hashData getBytes:bytes];
    
    NSMutableString *output = [[NSMutableString alloc] init];
    for(int i = 0; i < hashData.length; i++) {
        [output appendFormat:@"%02x", bytes[i]];
    }
    return output;
}


+ (NSData *)JPEGDataForCGImage:(CGImageRef)imageRef withQuality:(float)quality
{
  NSMutableData *outputData = [[NSMutableData alloc] init];
  CGImageDestinationRef destRef = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)outputData,
                                                                   kUTTypeJPEG,
                                                                   1,
                                                                   NULL);
  NSDictionary *properties = @{
                               (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(quality)
                               };
  
  CGImageDestinationSetProperties(destRef,
                                  (__bridge CFDictionaryRef)properties);
  
  CGImageDestinationAddImage(destRef,
                             imageRef,
                             NULL);
  CGImageDestinationFinalize(destRef);
  CFRelease(destRef);
  return outputData;
}


@end
