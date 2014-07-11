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
  
  
  return [NSArray arrayWithObjects:successReponse, errorResponse, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}



- (void)postAction:(DFPeanutAction *)action
withCompletionBlock:(DFPeanutActionResponseBlock)completionBlock
{
  NSDictionary *parameters = [action
                              dictionaryWithValuesForKeys:[DFPeanutAction simpleAttributeKeys]];
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutAction alloc] init]
                              method:RKRequestMethodPOST
                              path:ActionPostPath
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
     } else {
       DDLogVerbose(@"400 mapping result first object class: %@", [mappingResult.firstObject class]);
       NSError *error =
       [NSError errorWithDomain:@"com.duffapp.Strand"
                           code:-10
                       userInfo:@{
                                  NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%@", mappingResult.firstObject]
                                  }];
       completionBlock(nil, error);
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


@end
