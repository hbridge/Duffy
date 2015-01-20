//
//  DFPeanutPhotoAdapter.h
//  Strand
//
//  Created by Derek Parham on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutRestEndpointAdapter.h"

@interface DFPeanutPhotoAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)patchPhotos:(NSArray *)peanutPhotos
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;
@end
