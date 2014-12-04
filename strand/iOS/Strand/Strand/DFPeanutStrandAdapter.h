//
//  DFPeanutStrandAdapter.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RKHTTPUtilities.h>
#import "DFPeanutStrand.h"
#import "DFNetworkAdapter.h"
#import "DFPeanutFeedObject.h"

typedef void (^DFPeanutStrandFetchSuccess)(DFPeanutStrand *peanutStrand);
typedef void (^DFPeanutStrandFetchFailure)(NSError *error);

@interface DFPeanutStrandAdapter : NSObject <DFNetworkAdapter>

- (void)performRequest:(RKRequestMethod)requestMethod
        withPeanutStrand:(DFPeanutStrand *)peanutStrand
               success:(DFPeanutStrandFetchSuccess)success
               failure:(DFPeanutStrandFetchFailure)failure;


- (void)addPhotos:(NSArray *)photoObjects
       toStrandID:(DFStrandIDType)strandID
          success:(DFSuccessBlock)success
          failure:(DFFailureBlock)failure;

@end
