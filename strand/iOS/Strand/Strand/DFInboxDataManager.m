//
//  DFInboxDataManager.m
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxDataManager.h"

#import "DFPeanutStrandFeedAdapter.h"
#import "DFStrandConstants.h"

@interface DFInboxDataManager ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (nonatomic, retain) NSData *lastResponseHash;

@end

@implementation DFInboxDataManager

@synthesize feedAdapter = _feedAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(refreshFromServer)
                                               name:DFStrandReloadRemoteUIRequestedNotificationName
                                             object:nil];
}

#pragma mark - Data Fetch

- (void)refreshFromServer
{
  [self refreshFromServer:nil];
}

- (void)refreshFromServer:(void(^)(void))completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  
  [self.feedAdapter
   fetchInboxWithCompletion:^(DFPeanutObjectsResponse *response,
                              NSData *responseHash,
                              NSError *error) {
     [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
     
     if (!error && ![responseHash isEqual:self.lastResponseHash]) {
       self.lastResponseHash = responseHash;
       self.feedObjects = response.objects;
       
       [[NSNotificationCenter defaultCenter]
        postNotificationName:DFStrandNewInboxDataNotificationName
        object:self];
     }
     if (completion) completion();
   }
  ];
}

- (BOOL)hasData{
  return self.lastResponseHash;
}

#pragma mark - Network Adapter

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _feedAdapter;
}

@end

