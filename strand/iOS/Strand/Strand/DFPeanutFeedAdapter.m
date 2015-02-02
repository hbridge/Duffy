//
//  DFPeanutStrandFeedAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutFeedAdapter.h"
#import "DFObjectManager.h"

// Used
NSString *const PrivateStrandsPath = @"unshared_strands";
NSString *const InboxPath = @"swap_inbox";
NSString *const SwapsPath = @"swaps";
NSString *const ActionsListPath = @"actions_list";

// Not used
NSString *const GalleryPath = @"strand_feed";
NSString *const InvitedPath = @"invited_strands";
NSString *const SuggestedUnsharedPath = @"suggested_unshared_photos";
NSString *const ActivityPath = @"strand_activity";

@implementation DFPeanutFeedAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *paths = @[GalleryPath, PrivateStrandsPath, InvitedPath, SuggestedUnsharedPath, ActivityPath, InboxPath, SwapsPath, ActionsListPath];
  
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

// Used

- (void)fetchInboxWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters
{
  [super fetchObjectsAtPath:InboxPath withCompletionBlock:completionBlock parameters:parameters];
}

- (void)fetchAllPrivateStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters
{
  [super fetchObjectsAtPath:PrivateStrandsPath withCompletionBlock:completionBlock parameters:parameters];
}

- (void)fetchSwapsWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters
{
  [super fetchObjectsAtPath:SwapsPath withCompletionBlock:completionBlock parameters:parameters];
}

- (void)fetchActionsListWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters
{
  [super fetchObjectsAtPath:ActionsListPath withCompletionBlock:completionBlock parameters:parameters];
}


// Not Used
- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [super fetchObjectsAtPath:GalleryPath withCompletionBlock:completionBlock];
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


@end
