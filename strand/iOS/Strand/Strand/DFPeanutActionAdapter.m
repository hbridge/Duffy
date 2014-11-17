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
#import "DFPeanutAction.h"

NSString *const ActionBasePath = @"actions/";

@implementation DFPeanutActionAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  return [super responseDescriptorsForPeanutObjectClass:[DFPeanutAction class]
                                        basePath:ActionBasePath
                                     bulkKeyPath:nil];
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutAction class]
                                       bulkPostKeyPath:nil];
}



- (void)addAction:(DFPeanutAction *)action
                        success:(DFPeanutRestFetchSuccess)success
                        failure:(DFPeanutRestFetchFailure)failure
{
  
  [super
   performRequest:RKRequestMethodPOST
   withPath:ActionBasePath
   objects:@[action]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     if (success) success(resultObjects);
   } failure:^(NSError *error) {
     if (failure) failure(error);
   }];
}

- (void)removeAction:(DFPeanutAction *)action
             success:(DFPeanutRestFetchSuccess)success
             failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodDELETE
   withPath:ActionBasePath
   objects:@[action]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     if (success) success(resultObjects);
   } failure:^(NSError *error) {
     if (failure) failure(error);
   }];
}

@end
