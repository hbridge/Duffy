//
//  DFPeanutStrandFeedAdapter.h
//  Strand
//
//  Created by Henry Bridge on 9/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutObjectsAdapter.h"

@interface DFPeanutFeedAdapter : DFPeanutObjectsAdapter

// Used
- (void)fetchAllPrivateStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters;
- (void)fetchInboxWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters;
- (void)fetchSwapsWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters;
- (void)fetchActionsListWithCompletion:(DFPeanutObjectsCompletion)completionBlock parameters:(NSDictionary *)parameters;

// Deprecated
- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock;

- (void)fetchInvitedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock;
- (void)fetchSuggestedPhotosForStrand:(NSNumber *)strandID
                           completion:(DFPeanutObjectsCompletion)completionBlock;
- (void)fetchStrandActivityWithCompletion:(DFPeanutObjectsCompletion)completionBlock;

@end
