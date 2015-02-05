//
//  DFPeanutNotificationsAdapter.m
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutNotificationsAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutInvalidField.h"

NSString *const NotificationsGetPath = @"get_notifications/";

@implementation DFPeanutNotificationsAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutNotification rkObjectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:NotificationsGetPath
                                              keyPath:@"notifications"
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField rkObjectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:NotificationsGetPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restErrorResponse];
}

+ (NSArray *)requestDescriptors
{
  RKObjectMapping *mapping = [[DFPeanutNotification rkObjectMapping] inverseMapping];
  RKRequestDescriptor *restRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:[DFPeanutNotification class]
                                        rootKeyPath:@"notifications"
                                             method:RKRequestMethodGET];
  return @[restRequestDescriptor];
}

/*
 * Does a simple GET to the get_notifications url and maps the results to an array
 */
- (void)fetchNotifications:(DFPeanutNotificationsFetchSuccess)success
                   failure:(DFPeanutNotificationsFetchFailure)failure
{
  
  NSString *requestPath = NotificationsGetPath;
  NSURLRequest *request = [DFObjectManager
                           requestWithObject:nil
                           method:RKRequestMethodGET
                           path:requestPath
                           parameters:nil];
  
  DDLogInfo(@"%@ getting endpoint: %@ \n  bodySize:%lu \n",
            [[self class] description],
            request.URL.absoluteString,
            (unsigned long)request.HTTPBody.length);
  DDLogVerbose(@"%@ request body: %@",
               [self.class description],
               [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DDLogInfo(@"%@ response received with %d objects.",
               [self.class description],
               (int)mappingResult.count);
     success([mappingResult array]);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *betterError = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     DDLogWarn(@"%@ got error: %@", [self.class description], betterError);
     failure(betterError);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];

}
@end
