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

@implementation DFDataHasher

static const unsigned int ALAssetHashBytesLength = 1024 * 8;

+ (NSData *)hashDataForData:(NSData *)inputData
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(inputData.bytes, inputData.length, digest);
    
    return [NSData dataWithBytes:&digest length:CC_SHA1_DIGEST_LENGTH];
}


+ (NSData *)hashDataForALAsset:(ALAsset *)asset
{
    uint8_t assetBytesToHash[ALAssetHashBytesLength];
    
    NSError *error;
    [asset.defaultRepresentation getBytes:assetBytesToHash fromOffset:0 length:ALAssetHashBytesLength error:&error];
    if (error) {
        [NSException raise:@"Could not hash ALAsset"
                    format:@"Hashing ALAsset %@ failed: %@", [asset valueForProperty:ALAssetPropertyAssetURL], [error localizedDescription]];
    }
    
    return [NSData dataWithBytes:assetBytesToHash length:ALAssetHashBytesLength];
}



@end
