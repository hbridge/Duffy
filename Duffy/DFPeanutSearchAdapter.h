//
//  DFPeanutSearchAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutSearchResponse.h"

@interface DFPeanutSearchAdapter : NSObject <DFNetworkAdapter>


typedef void (^DFSearchFetchCompletionBlock)(DFPeanutSearchResponse *response);

- (void)fetchSearchResultsForQuery:(NSString *)query
                        maxResults:(NSUInteger)maxResults
                     minDateString:(NSString *)minDateString
               withCompletionBlock:(DFSearchFetchCompletionBlock)completionBlock;




@end
