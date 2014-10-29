//
//  DFImageManagerRequest.m
//  Strand
//
//  Created by Henry Bridge on 10/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageManagerRequest.h"
#import "DFPhotoAsset.h"

@implementation DFImageManagerRequest

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                           size:(CGSize)size
                    contentMode:(DFImageRequestContentMode)contentMode
                   deliveryMode:(DFImageRequestDeliveryMode)deliveryMode
{
  self = [super init];
  if (self) {
    _photoID = photoID;
    _size = size;
    _contentMode = contentMode;
    _deliveryMode = deliveryMode;
  }
  return self;
}

- (NSUInteger)hash
{
  return (NSUInteger)self.photoID + self.size.width + self.size.height + self.contentMode + self.deliveryMode;
}

- (BOOL)isEqual:(id)object
{
  DFImageManagerRequest *otherObject = object;
  if (otherObject.photoID == self.photoID
      && CGSizeEqualToSize(self.size, otherObject.size)
      && otherObject.contentMode == self.contentMode
      && otherObject.deliveryMode == self.deliveryMode) {
    return YES;
  }
  
  return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
  DFImageManagerRequest *newObject = [[DFImageManagerRequest allocWithZone:zone]
                                      initWithPhotoID:self.photoID
                                      size:self.size
                                      contentMode:self.contentMode
                                      deliveryMode:self.deliveryMode];
  
  return newObject; 
}

- (DFImageType)imageType
{
  DFImageType imageRequestType;
  if (self.size.width <= DFPhotoAssetDefaultThumbnailSize
      && self.size.height <= DFPhotoAssetDefaultThumbnailSize) {
    imageRequestType = DFImageThumbnail;
  } else {
    imageRequestType = DFImageFull;
  }
  return imageRequestType;
}

- (BOOL)isDefaultThumbnail
{
  return CGSizeEqualToSize(self.size, CGSizeMake(DFPhotoAssetDefaultThumbnailSize,
                                                 DFPhotoAssetDefaultThumbnailSize));
}

- (DFImageManagerRequest *)copyWithPhotoID:(DFPhotoIDType)photoID
{
  return [[DFImageManagerRequest alloc] initWithPhotoID:photoID
                                                   size:self.size
                                            contentMode:self.contentMode
                                           deliveryMode:self.deliveryMode];
}

- (DFImageManagerRequest *)copyWithDeliveryMode:(DFImageRequestDeliveryMode)deliveryMode
{
  return [[DFImageManagerRequest alloc] initWithPhotoID:self.photoID
                                                   size:self.size
                                            contentMode:self.contentMode 
                                           deliveryMode:deliveryMode];
}

- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:@[@"photoID", @"size", @"contentMode", @"deliveryMode"]]
          description];
}

@end
