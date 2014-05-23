//
//  DFAutocompleteAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "DFNetworkAdapter.h"

@interface DFAutocompleteAdapter : NSObject 


typedef void (^DFAutocompleteFetchCompletionBlock)(NSArray *peanutAutocompleteResults);

- (void)fetchResultsForQuery:(NSString *)query
         withCompletionBlock:(DFAutocompleteFetchCompletionBlock)completionBlock;

@end
