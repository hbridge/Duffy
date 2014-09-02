//
//  DFPeanutStrandInviteAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandInviteAdapter.h"
#import "DFPeanutStrandInvite.h"

NSString *const StrandInviteBasePath = @"strand_invite/";

@implementation DFPeanutStrandInviteAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  return [super responseDescriptorsForPeanutObjectClass:[DFPeanutStrandInvite class]
                                               basePath:StrandInviteBasePath
                                            bulkKeyPath:@"strandInvites"];
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutStrandInvite class]
                                           rootKeyPath:@"strandInvites"];
}

- (void)postInvites:(NSArray *)peanutStrandInvites
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;
{
  [super
   performRequest:RKRequestMethodPOST
   withPath:StrandInviteBasePath
   objects:peanutStrandInvites
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(success);
   } failure:^(NSError *error) {
     failure(failure);
   }];
}


@end
