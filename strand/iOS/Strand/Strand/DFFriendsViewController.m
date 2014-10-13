//
//  DFFriendsViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendsViewController.h"
#import "DFPeanutUserObject.h"

@interface DFFriendsViewController ()

@property (nonatomic, strong) NSArray *friendPeanutUsers;

@end

@implementation DFFriendsViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureTabAndNav];
    _friendPeanutUsers = [self.class mockPeanutUsers];
  }
  return self;
}

- (void)configureTabAndNav
{
  self.navigationItem.title = @"Friends";
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
}

+ (NSArray *)mockPeanutUsers
{
  DFPeanutUserObject *aseem = [[DFPeanutUserObject alloc] init];
  aseem.display_name = @"aseem";
  DFPeanutUserObject *derek = [[DFPeanutUserObject alloc] init];
  derek.display_name = @"derek";
  
  return @[
           aseem,
           derek
           ];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureTableView:(UITableView *)tableView
{
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.friendPeanutUsers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  
  DFPeanutUserObject *peanutUser = self.friendPeanutUsers[indexPath.row];
  cell.textLabel.text = peanutUser.display_name;
  return cell;
}

@end
