//
//  DFPeanutStrandFeedAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandFeedAdapter.h"
#import "DFObjectManager.h"

NSString *const PrivatePhotosPath = @"unshared_strands";
NSString *const GalleryPath = @"strand_feed";
NSString *const InvitedPath = @"invited_strands";
NSString *const SuggestedUnsharedPath = @"suggested_unshared_photos";
NSString *const ActivityPath = @"strand_activity";
NSString *const InboxPath = @"strand_inbox";

@implementation DFPeanutStrandFeedAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *paths = @[GalleryPath, PrivatePhotosPath, InvitedPath, SuggestedUnsharedPath, ActivityPath, InboxPath];
  
  NSMutableArray *responseDescriptors = [NSMutableArray new];
  for (NSString *path in paths) {
    RKResponseDescriptor *descriptor = [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                                                                    method:RKRequestMethodAny
                                                                               pathPattern:path
                                                                                   keyPath:nil
                                                                               statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [responseDescriptors addObject:descriptor];
  }
  
  return responseDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:GalleryPath withCompletionBlock:completionBlock];
}

- (void)fetchAllPrivateStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:PrivatePhotosPath withCompletionBlock:completionBlock];
}

- (void)fetchInvitedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:InvitedPath withCompletionBlock:completionBlock];
}

- (void)fetchSuggestedPhotosForStrand:(NSNumber *)strandID
                           completion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:SuggestedUnsharedPath
        withCompletionBlock:completionBlock
                 parameters:@{@"strand_id": strandID}];
}

- (void)fetchStrandActivityWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:ActivityPath withCompletionBlock:completionBlock];
}

- (void)fetchInboxWithCompletion:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:InboxPath withCompletionBlock:completionBlock];
}

@end
