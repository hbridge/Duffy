//
//  DFAutocompleteController.m
//  Duffy
//
//  Created by Henry Bridge on 4/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSuggestionAdapter.h"
#import <RestKit/RestKit.h>
#import "DFUser.h"

// Private DFAutocompleteResponse Class
@interface DFPeanutSuggestionResponse : NSObject
@property (nonatomic, retain) NSString *result;
@property (nonatomic, retain) NSArray *top_times;
@property (nonatomic, retain) NSArray *top_locations;
@property (nonatomic, retain) NSArray *top_categories;
@end
@implementation DFPeanutSuggestionResponse
@end

@interface DFSuggestionAdapter()

@property (readonly, atomic, retain) RKObjectManager* objectManager;

@end

@implementation DFSuggestionAdapter

@synthesize objectManager = _objectManager;

static NSString *SuggestionsPathPattern = @"get_suggestions";
static NSString *UserIDParameterKey = @"user_id";


- (void)fetchSuggestions:(DFSuggestionCompletionBlock)mainThreadCompletionBlock
{
    if ([[DFUser currentUser] userID]) {
        [self fetchAutocompleteResults:mainThreadCompletionBlock];
    } else {
        mainThreadCompletionBlock(nil, nil, nil);
    }
}



#pragma mark - Internal Network Fetch Functions


- (void)fetchAutocompleteResults:(DFSuggestionCompletionBlock)completionBlock
{
    NSURLRequest *getRequest = [self autocompleteGetRequest];
    
    RKObjectRequestOperation *operation =
    [[self objectManager]
     objectRequestOperationWithRequest:getRequest
     success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
     {
         DFPeanutSuggestionResponse *response = [mappingResult firstObject];
         DDLogVerbose(@"Autocomplete response received.  result:%@", response.result);

         if ([response.result isEqualToString:@"true"]) {
           dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(response.top_categories, response.top_locations, response.top_times);
           });
         }  else {
           completionBlock(nil, nil, nil);
         }

     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         DDLogWarn(@"Autocomplete fetch failed.  Error: %@", error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(nil, nil, nil);
         });
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (NSMutableURLRequest *)autocompleteGetRequest
{
    NSMutableURLRequest *request = [[self objectManager] requestWithObject:[[DFPeanutSuggestionResponse alloc] init]
                                                                    method:RKRequestMethodGET
                                                                      path:SuggestionsPathPattern
                                                                parameters:@{UserIDParameterKey: [NSNumber numberWithUnsignedLongLong:[[DFUser currentUser] userID]]}];
    
    return request;
}

#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] apiURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];

        RKObjectMapping *autocompleteResponseMapping = [RKObjectMapping mappingForClass:[DFPeanutSuggestionResponse class]];
        [autocompleteResponseMapping addAttributeMappingsFromArray:@[@"result"]];

        
        RKObjectMapping *suggestionMapping = [DFPeanutSuggestion objectMapping];
      
        [autocompleteResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"top_times"
                                                                                                    toKeyPath:@"top_times"
                                                                                                  withMapping:suggestionMapping]];
        [autocompleteResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"top_locations"
                                                                                                    toKeyPath:@"top_locations"
                                                                                                  withMapping:suggestionMapping]];
        [autocompleteResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"top_categories"
                                                                                                    toKeyPath:@"top_categories"
                                                                                                  withMapping:suggestionMapping]];


        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:autocompleteResponseMapping
                                                                                                method:RKRequestMethodGET
                                                                                           pathPattern:SuggestionsPathPattern
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
}

@end
