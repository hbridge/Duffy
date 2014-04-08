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
@end
@implementation DFAutocompleteResponse
@end

@interface DFLocation : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSNumber *count;
@end
@implementation DFLocation
@end


@interface DFAutocompleteController()

@property (readonly, atomic, retain) RKObjectManager* objectManager;

@end

@implementation DFAutocompleteController

@synthesize objectManager = _objectManager;

static NSString *TopLocationsPathPattern = @"/api/get_top_locations";
static NSString *UserIDParameterKey = @"user_id";


- (void)topLocationsAndCounts:(DFAutocompleteCompletionBlock)mainThreadCompletionBlock
{
    if ([[DFUser currentUser] userID]) {
        [self fetchAutocompleteResults:mainThreadCompletionBlock];
    } else {
        mainThreadCompletionBlock(nil);
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

         NSDictionary *result;
         if ([response.result isEqualToString:@"true"]) {
             NSMutableDictionary *entriesAndCounts = [[NSMutableDictionary alloc] init];
             for (DFLocation *location in response.top_locations) {
                 entriesAndCounts[location.name] = location.count;
             }
             result = entriesAndCounts;
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

        //Aseem format
//        RKObjectMapping *autocompleteResponseMapping = [RKObjectMapping mappingForClass:[DFAutocompleteResponse class]];
//        [autocompleteResponseMapping addAttributeMappingsFromArray:@[@"result"]];
//
//        RKObjectMapping *locationMapping = [RKObjectMapping mappingForClass:[DFLocation class]];
//        [locationMapping addAttributeMappingsFromDictionary:@{@"name": @"name",
//                                                              @"count" : @"count"
//                                                              }];
//        
//        [autocompleteResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"top_locations"
//                                                                                                    toKeyPath:@"top_locations"
//                                                                                                  withMapping:locationMapping]];
        // Derek format
        
        RKObjectMapping *autocompleteResponseMapping = [RKObjectMapping mappingForClass:[DFAutocompleteResponse class]];
        [autocompleteResponseMapping addAttributeMappingsFromArray:@[@"result"]];

        RKObjectMapping *locationMapping = [RKObjectMapping mappingForClass:[DFLocation class]];
        locationMapping.forceCollectionMapping = YES;
        [locationMapping addAttributeMappingFromKeyOfRepresentationToAttribute:@"name"];
        [locationMapping addPropertyMapping:[RKAttributeMapping attributeMappingFromKeyPath:@"(name)" toKeyPath:@"count"]];

        [autocompleteResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"top_locations"
                                                                                                    toKeyPath:@"top_locations"
                                                                                                  withMapping:locationMapping]];

        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:autocompleteResponseMapping
                                                                                                method:RKRequestMethodGET
                                                                                           pathPattern:TopLocationsPathPattern
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
}

@end
