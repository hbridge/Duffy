//
//  DFPeanutSuggestedStrandsAdapter.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutSuggestedStrandsAdapter.h"
#import "DFObjectManager.h"

NSString *const UnsharedPath = @"unshared_strands";

@implementation DFPeanutSuggestedStrandsAdapter


+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *galleryResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:UnsharedPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:galleryResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}


- (void)fetchSuggestedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:UnsharedPath withCompletionBlock:completionBlock];
}


@end
