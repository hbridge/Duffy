//
//  DFPeanutStrandFeedAdapter.h
//  Strand
//
//  Created by Henry Bridge on 9/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutObjectsAdapter.h"

@interface DFPeanutStrandFeedAdapter : DFPeanutObjectsAdapter

- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock;
- (void)fetchSuggestedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock;
- (void)fetchInvitedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock;


@end
