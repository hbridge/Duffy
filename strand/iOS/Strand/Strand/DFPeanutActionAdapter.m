//
//  DFPeanutActionAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutActionAdapter.h"
#import "DFObjectManager.h"
#import "RestKit/RestKit.h"
#import "DFPeanutInvalidField.h"

NSString *const ActionPostPath = @"photo_actions/";
NSString *const ActionIDPath = @"photo_actions/:id/";

@implementation DFPeanutActionAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *successReponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutAction objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:ActionPostPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  RKResponseDescriptor *errorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:ActionPostPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  RKResponseDescriptor *actionErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:ActionIDPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  
  return [NSArray arrayWithObjects:successReponse, errorResponse, actionErrorResponse, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}


- (void)performAction:(DFPeanutAction *)action
    withRequestMethod:(RKRequestMethod)method
         useActionURL:(BOOL)useActionURL
      completionBlock:(DFPeanutActionResponseBlock)completionBlock
{
  NSDictionary *parameters = [action
                              dictionaryWithValuesForKeys:[DFPeanutAction simpleAttributeKeys]];
  
  NSString *path = ActionPostPath;
  if (useActionURL) {
    path = [NSString stringWithFormat:@"%@%@", ActionPostPath, @(action.id)];
  }
  
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutAction alloc] init]
                              method:method
                              path:path
                              parameters:parameters
                              ];
  DDLogInfo(@"%@ getting endpoint: %@, parameters:%@", [[self class] description],
            getRequest.URL.absoluteString,
            parameters.description);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutAction class]]) {
       DFPeanutAction *action = mappingResult.firstObject;
       DDLogInfo(@"%@ created peanut action with id: %llu", [self.class description], action.id);
       completionBlock(action, nil);
     } else if (method == RKRequestMethodDELETE && mappingResult == nil) {
       DDLogInfo(@"%@ deleted peanut action with id: %llu", [self.class description], action.id);
     } else {
       DDLogError(@"%@ unexpected response: %@", [self.class description], mappingResult.firstObject);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSMutableString *invalidFieldsString = [[NSMutableString alloc] init];
     NSArray *invalidFields = error.userInfo[RKObjectMapperErrorObjectsKey];
     if (invalidFields && invalidFields.count > 0) {
       for (DFPeanutInvalidField *invalidField in invalidFields) {
         [invalidFieldsString appendString:[NSString stringWithFormat:@"%@: %@. ",
                                            invalidField.field_name,
                                            invalidField.field_errors.firstObject]];
       }
     }
     
     NSError *betterError;
     DDLogWarn(@"%@ get failed.  Error: %@ Invalid fields: %@",
               [[self class] description],
               error.description,
               invalidFieldsString);
     if (![invalidFieldsString isEqualToString:@""]) {
       betterError = [NSError errorWithDomain:@"com.duffyapp.duffy"
                                         code:-11 userInfo:@{
                                                             NSLocalizedDescriptionKey: invalidFieldsString
                                                             }];
     }
     
     if (betterError) {
       completionBlock(nil, betterError);
     } else {
       completionBlock(nil, error);
     }
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}

- (void)postAction:(DFPeanutAction *)action
withCompletionBlock:(DFPeanutActionResponseBlock)completionBlock
{
  [self performAction:action
    withRequestMethod:RKRequestMethodPOST
         useActionURL:NO
      completionBlock:completionBlock];
}

- (void)deleteAction:(DFPeanutAction *)action
 withCompletionBlock:(DFPeanutActionResponseBlock)completionBlock
{
  [self performAction:action
    withRequestMethod:RKRequestMethodDELETE
   useActionURL:YES
      completionBlock:completionBlock];
}


@end
