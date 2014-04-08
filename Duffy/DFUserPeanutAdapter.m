//
//  DFUserIDFetcher.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUserPeanutAdapter.h"
#import <RestKit/RestKit.h>
#import "DFNetworkingConstants.h"
#import "DFUser.h"

@interface DFUserInfoFetchResponse : NSObject
@property (nonatomic, retain) NSString *result;
@property (nonatomic, retain) DFUser *user;
@end
@implementation DFUserInfoFetchResponse
@end


@interface DFUserPeanutAdapter()

@property (readonly, atomic, retain) RKObjectManager* objectManager;

@end

@implementation DFUserPeanutAdapter

@synthesize objectManager = _objectManager;


#pragma mark - Internal Network Fetch Functions


- (void)fetchUserForDeviceID:(NSString *)deviceId
            withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                failureBlock:(DFUserFetchFailureBlock)failureBlock
{
    NSURLRequest *getRequest = [[self objectManager] requestWithObject:[[DFUserInfoFetchResponse alloc] init]
                                                                    method:RKRequestMethodGET
                                                                      path:DFGetUserPath
                                                                parameters:@{DFDeviceIDParameterKey: deviceId}];
    
    RKObjectRequestOperation *operation =
    [[self objectManager]
     objectRequestOperationWithRequest:getRequest
     success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
     {
         DFUserInfoFetchResponse *response = [mappingResult firstObject];
         NSLog(@"User Info response received.  result:%@", response.result);
         
         DFUser *result;
         if ([response.result isEqualToString:@"true"]) {
             result = response.user;
         }  else {
             result = nil;
         }
         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
             successBlock(result);
         });
     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         NSLog(@"User Info fetch failed.  Error: %@", error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             failureBlock(error);
         });
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation];
}

- (void)createUserForDeviceID:(NSString *)deviceId
             withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                 failureBlock:(DFUserFetchFailureBlock)failureBlock
{
    NSURLRequest *createRequest = [[self objectManager] requestWithObject:[[DFUserInfoFetchResponse alloc] init]
                                                                method:RKRequestMethodAny
                                                                  path:DFCreateUserPath
                                                            parameters:@{DFDeviceIDParameterKey: deviceId}];
    
    RKObjectRequestOperation *operation =
    [[self objectManager]
     objectRequestOperationWithRequest:createRequest
     success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
     {
         DFUserInfoFetchResponse *response = [mappingResult firstObject];
         NSLog(@"User create response received.  result:%@", response.result);
         
         DFUser *result;
         if ([response.result isEqualToString:@"true"]) {
             result = response.user;
         }  else {
             result = nil;
         }
         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
             successBlock(result);
         });
     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         NSLog(@"User create failed.  Error: %@", error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             failureBlock(error);
         });
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation];
}





#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] serverURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];
        
        //Aseem format
        RKObjectMapping *userInfoResponseMapping = [RKObjectMapping mappingForClass:[DFUserInfoFetchResponse class]];
        [userInfoResponseMapping addAttributeMappingsFromArray:@[@"result"]];
        
        RKObjectMapping *userDataMapping = [RKObjectMapping mappingForClass:[DFUser class]];
        [userDataMapping addAttributeMappingsFromDictionary:@{@"first_name": @"firstName",
                                                                  @"last_name" : @"lastName",
                                                                  @"phone_id" : @"hardwareDeviceID",
                                                                  @"id" : @"userID",
                                                                  }];
        
        [userInfoResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"user"
                                                                                                    toKeyPath:@"user"
                                                                                                  withMapping:userDataMapping]];
        
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userInfoResponseMapping
                                                                                                method:RKRequestMethodGET
                                                                                           pathPattern:DFGetUserPath
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
}


@end
