//
//  DFPeanutLocationAdapter.m
//  Strand
//
//  Created by Henry Bridge on 6/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutLocationAdapter.h"
#import <Restkit/RestKit.h>
#import "DFObjectManager.h"
#import "DFPeanutTrueFalseResponse.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"


static NSString *const UpdateLocationPath = @"update_user_location";
static NSString *const LatitudeKey = @"lat";
static NSString *const LongitudeKey = @"lon";
static NSString *const TimestampKey = @"timestamp";
static NSString *const AccuracyKey = @"accuracy";

@implementation DFPeanutLocationAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *trueFalseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutTrueFalseResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:UpdateLocationPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:trueFalseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)updateLocation:(CLLocation *)location
         withTimestamp:(NSDate *)date
              accuracy:(CLLocationAccuracy)accuracy
       completionBlock:(DFUpdateLocationResponseBlock)completionBlock;
{
  NSString *timestampString = [[NSDateFormatter DjangoDateFormatter] stringFromDate:date];
  if (!timestampString) timestampString = @"";
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutTrueFalseResponse alloc] init]
                              method:RKRequestMethodGET
                              path:UpdateLocationPath
                              parameters:@{
                                           LatitudeKey: @(location.coordinate.latitude),
                                           LongitudeKey: @(location.coordinate.longitude),
                                           TimestampKey: timestampString,
                                           AccuracyKey: @(location.horizontalAccuracy),
                                           }];
  DDLogVerbose(@"DFPeanutLocationAdapter getting endpoint: %@", getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutTrueFalseResponse class]]){
       DFPeanutTrueFalseResponse *response = mappingResult.firstObject;
       completionBlock(response.result);
     } else {
       DDLogWarn(@"Updating location resulted in a non true false response.  Mapping result: %@",
                 mappingResult.description);
       completionBlock(NO);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Updating location failed.  Error: %@", error.description);
     completionBlock(NO);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}


@end
