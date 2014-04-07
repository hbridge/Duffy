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
@property NSString *result;
@end
@implementation DFAutocompleteResponse
@end

@interface DFTopLocationsRelationship : NSObject
@property NSDictionary *top_locations;
@end
@implementation DFTopLocationsRelationship
@end


@interface DFAutocompleteController()

@property (readonly, atomic, retain) RKObjectManager* objectManager;

@end

@implementation DFAutocompleteController

@synthesize objectManager = _objectManager;

static NSString *TopLocationsPathPattern = @"api/get_top_locations";
static NSString *UserIDParameterKey = @"user_id";


- (void)topLocationsAndCounts:(DFAutocompleteCompletionBlock)mainThreadCompletionBlock
{
    
    [self fetchAutocompleteResults:mainThreadCompletionBlock];
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

         NSDictionary *result;
         if ([response.result isEqualToString:@"true"]) {
             //result = response.top_locations;
         }  else {
             result = nil;
         }
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(result);
         });

     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         NSLog(@"Autocomplete fetch failed.  Error: %@", error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(nil);
         });
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (NSMutableURLRequest *)autocompleteGetRequest
{
    NSMutableURLRequest *request = [[self objectManager] requestWithObject:[[DFAutocompleteResponse alloc] init]
                                                                    method:RKRequestMethodGET
                                                                      path:TopLocationsPathPattern
                                                                parameters:@{UserIDParameterKey: [[DFUser currentUser] userID]}];
    
    return request;
}

#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] serverURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];
        
        RKObjectMapping *autocompleteResponseMapping = [RKObjectMapping mappingForClass:[DFAutocompleteResponse class]];
       [autocompleteResponseMapping addAttributeMappingsFromArray:@[@"result", @"top_locations"]];
        
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:autocompleteResponseMapping
                                                                                                method:RKRequestMethodPOST
                                                                                           pathPattern:TopLocationsPathPattern
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
}

@end
