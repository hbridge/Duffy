//
//  DFAutocompleteController.h
//  Duffy
//
//  Created by Henry Bridge on 4/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFAutocompleteController : NSObject


typedef void (^DFAutocompleteCompletionBlock)(NSDictionary *entriesAndCounts);


- (void)topLocationsAndCounts:(DFAutocompleteCompletionBlock)mainThreadCompletionBlock;


@end
