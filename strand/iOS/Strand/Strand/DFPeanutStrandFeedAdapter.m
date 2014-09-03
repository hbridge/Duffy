//
//  DFPeanutStrandFeedAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandFeedAdapter.h"
#import "DFObjectManager.h"

NSString *const UnsharedPath = @"unshared_strands";
NSString *const GalleryPath = @"strand_feed";
NSString *const InvitedPath = @"invited_strands";

@implementation DFPeanutStrandFeedAdapter

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

  RKResponseDescriptor *suggestedResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:UnsharedPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *invitedResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:InvitedPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  return @[galleryResponseDescriptor, suggestedResponseDescriptor, invitedResponseDescriptor];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:GalleryPath withCompletionBlock:completionBlock];
}

- (void)fetchSuggestedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:UnsharedPath withCompletionBlock:completionBlock];
}

- (void)fetchInvitedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:InvitedPath withCompletionBlock:completionBlock];
}


@end
