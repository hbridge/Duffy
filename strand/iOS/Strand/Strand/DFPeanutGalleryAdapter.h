//
//  DFPeanutGalleryAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutObjectsAdapter.h"

@interface DFPeanutGalleryAdapter : DFPeanutObjectsAdapter <DFNetworkAdapter>

- (void)fetchGalleryWithCompletionBlock:(DFPeanutObjectsCompletion)completionBlock;

@end
