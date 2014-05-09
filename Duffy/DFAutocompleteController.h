//
//  DFAutocompleteController.h
//  Duffy
//
//  Created by Henry Bridge on 4/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutSuggestion.h"

@interface DFAutocompleteController : NSObject

typedef void (^DFAutocompleteCompletionBlock)(NSArray *categoryPeanutSuggestions,
                                              NSArray *locationPeanutSuggestions,
                                              NSArray *timePeanutSuggestions);

- (void)fetchSuggestions:(DFAutocompleteCompletionBlock)mainThreadCompletionBlock;

@end
