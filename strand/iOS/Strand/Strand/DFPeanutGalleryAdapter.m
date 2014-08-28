//
//  DFPeanutGalleryAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutGalleryAdapter.h"
#import "DFObjectManager.h"

NSString *const GalleryPath = @"strand_feed";

@implementation DFPeanutGalleryAdapter 


+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *galleryResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:GalleryPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:galleryResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}


- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:GalleryPath withCompletionBlock:completionBlock];
}



@end
