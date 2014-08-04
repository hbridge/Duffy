//
//  DFUserInfoManager.m
//  Strand
//
//  Created by Henry Bridge on 8/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUserInfoManager.h"
#import "DFNotificationSharedConstants.h"
#import "DFStrandConstants.h"
#import "DFUserPeanutAdapter.h"

static NSTimeInterval minFetchInterval = 1.0;

@interface DFUserInfoManager()

@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;
@property (nonatomic, retain) NSDate *lastFetchDate;

@end


@implementation DFUserInfoManager

@synthesize userAdapter = _userAdapter;

// We want the upload controller to be a singleton
static DFUserInfoManager *defaultManager;
+ (DFUserInfoManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (id)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(galleryAppeared:)
                                                 name:DFStrandGalleryAppearedNotificationName
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(update)
                                                 name:DFStrandRefreshRemoteUIRequestedNotificationName
                                               object:nil];
  }
  return self;
}


- (void)galleryAppeared:(NSNotification *)note
{
  [self update];
}

- (void)update
{
  if ([[NSDate date] timeIntervalSinceDate:self.lastFetchDate] < minFetchInterval) {
    return;
  }
  
  DFPeanutUserObject *currentUserPeanutObject = [DFPeanutUserObject new];
  currentUserPeanutObject.id = [[DFUser currentUser] userID];
  [self.userAdapter performRequest:RKRequestMethodGET
                    withPeanutUser:currentUserPeanutObject
                           success:^(DFPeanutUserObject *user) {
                             
                           } failure:^(NSError *error) {
                             
                           }];
}


- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) {
    _userAdapter = [[DFUserPeanutAdapter alloc] init];
  }
  return _userAdapter;
}

@end
