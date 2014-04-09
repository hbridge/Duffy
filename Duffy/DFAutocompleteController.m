//
//  DFAutocompleteController.m
//  Duffy
//
//  Created by Henry Bridge on 4/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAutocompleteController.h"
#import <RestKit/RestKit.h>
#import "DFUser.h"

// Private DFAutocompleteResponse Class
@interface DFAutocompleteResponse : NSObject
@property (nonatomic, retain) NSString *result;
@property (nonatomic, retain) NSArray *top_locations;
@property (nonatomic, retain) NSArray *top_categories;
@end
@implementation DFAutocompleteResponse
@end

@interface DFSuggestion : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSNumber *count;
@end
@implementation DFSuggestion
@end



@interface DFAutocompleteController()

@property (readonly, atomic, retain) RKObjectManager* objectManager;

@end

@implementation DFAutocompleteController

@synthesize objectManager = _objectManager;

static NSString *SuggestionsPathPattern = @"/api/get_suggestions";
//static NSString *TopLocationsPathPattern = @"/api/get_top_locations";
static NSString *UserIDParameterKey = @"user_id";


- (void)fetchSuggestions:(DFAutocompleteCompletionBlock)mainThreadCompletionBlock
{
    if ([[DFUser currentUser] userID]) {
        [self fetchAutocompleteResults:mainThreadCompletionBlock];
    } else {
        mainThreadCompletionBlock(nil, nil);
    }
}



#pragma mark - Internal Network Fetch Functions


- (void)fetchAutocompleteResults:(DFAutocompleteCompletionBlock)completionBlock
{
    NSURLRequest *getRequest = [self autocompleteGetRequest];
    
    RKObjectRequestOperation *operation =
    [[self objectManager]
     objectRequestOperationWithRequest:getRequest
     success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
     {
         DFAutocompleteResponse *response = [mappingResult firstObject];
         NSLog(@"Autocomplete response received.  result:%@", response.result);

         NSDictionary *locationResult, *categoryResult;
         if ([response.result isEqualToString:@"true"]) {
             NSMutableDictionary *entriesAndCounts = [[NSMutableDictionary alloc] init];
             for (DFSuggestion *locationSuggestion in response.top_locations) {
                 if (locationSuggestion.name) {
                     entriesAndCounts[locationSuggestion.name] = locationSuggestion.count;
                 }
             }
             locationResult = entriesAndCounts;
             
             entriesAndCounts = [[NSMutableDictionary alloc] init];
             for (DFSuggestion *categorySuggestion in response.top_categories) {
                 if (categorySuggestion.name) {
                     entriesAndCounts[categorySuggestion.name] = categorySuggestion.count;
                 }
             }
             categoryResult = entriesAndCounts;
             
             
         }  else {
             locationResult = categoryResult = nil;
         }
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(categoryResult, locationResult);
         });

     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         NSLog(@"Autocomplete fetch failed.  Error: %@", error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(nil, nil);
         });
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (NSMutableURLRequest *)autocompleteGetRequest
{
    NSMutableURLRequest *request = [[self objectManager] requestWithObject:[[DFAutocompleteResponse alloc] init]
                                                                    method:RKRequestMethodGET
                                                                      path:SuggestionsPathPattern
                                                                parameters:@{UserIDParameterKey: [[DFUser currentUser] userID]}];
    
    return request;
}

#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] serverURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];

        //Aseem format
        RKObjectMapping *autocompleteResponseMapping = [RKObjectMapping mappingForClass:[DFAutocompleteResponse class]];
        [autocompleteResponseMapping addAttributeMappingsFromArray:@[@"result"]];

        
        RKObjectMapping *suggestionMapping = [RKObjectMapping mappingForClass:[DFSuggestion class]];
        [suggestionMapping addAttributeMappingsFromDictionary:@{@"name": @"name",
                                                                        @"count" : @"count"
                                                                        }];

//        RKObjectMapping *locationSuggestionMapping = [RKObjectMapping mappingForClass:[DFSuggestion class]];
//        [locationSuggestionMapping addAttributeMappingsFromDictionary:@{@"name": @"name",
//                                                              @"count" : @"count"
//                                                              }];
//        RKObjectMapping *categorySuggestionMapping = [RKObjectMapping mappingForClass:[DFSuggestion class]];
//        [categorySuggestionMapping addAttributeMappingsFromDictionary:@{@"name": @"name",
//                                                                @"count" : @"count"
//                                                                }];
        
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
