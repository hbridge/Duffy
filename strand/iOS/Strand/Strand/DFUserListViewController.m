//
//  DFUserListViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFUserListViewController.h"
#import "DFFriendProfileViewController.h"
#import "DFPeanutFeedDataManager.h"

@interface DFUserListViewController ()

@end

@implementation DFUserListViewController

- (instancetype)initWithUsers:(NSArray *)users
{
  self = [super init];
  if (self) {
    _users = users;
    self.allowsMultipleSelection = NO;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [super removeSearchBar];
  [self reloadData];
}


- (void)reloadData
{
  NSArray *peanutContacts = [self.users arrayByMappingObjectsWithBlock:^id(DFPeanutUserObject *user) {
    // look up full info in case it's incomplete
    DFPeanutUserObject *fullUser = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:user.phone_number];
    if (fullUser) {
      return [[DFPeanutContact alloc] initWithPeanutUser:fullUser];
    }
    return [[DFPeanutContact alloc] initWithPeanutUser:user];
  }];
  DFSection *section = [DFSection sectionWithTitle:@"People" object:nil rows:peanutContacts];
  [super setSections:@[section]];
}

@end
