//
//  DFSingleFriendViewController.m
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSingleFriendViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFLargeCardTableViewCell.h"
#import "DFFeedViewController.h"
#import "DFPeanutUserObject.h"
#import "DFPeanutFeedObject.h"

@interface DFSingleFriendViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *manager;
@property (nonatomic, retain) DFPeanutUserObject *userToView;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;

@end

@implementation DFSingleFriendViewController


- (instancetype)initWithUser:(DFPeanutUserObject *)userToView
{
  self = [super init];
  if (self) {
    self.manager = [DFPeanutFeedDataManager sharedManager];
    self.userToView = userToView;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self configureTableView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)configureTableView
{
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFLargeCardTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"strandCell"];
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"unknown"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSArray *strands = [self.manager strandsWithUser:self.userToView];
  
  return strands.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  NSArray *strands = [self.manager strandsWithUser:self.userToView];
  DFPeanutFeedObject *strandPosts = strands[indexPath.row];
  
  cell = [self cellWithStrandObject:strandPosts forTableView:tableView];
  
  return cell;
}

- (UITableViewCell *)cellWithStrandObject:(DFPeanutFeedObject *)strandPosts
                                      forTableView:(UITableView *)tableView
{
  DFLargeCardTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"strandCell"];
  [cell configureWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
  
  [cell setPhotosWithStrandPosts:strandPosts];

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *strands = [self.manager strandsWithUser:self.userToView];
  DFPeanutFeedObject *strandPosts = strands[indexPath.row];
  
  DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] init];
  photoFeedController.strandPostsObject = strandPosts;
  [self.navigationController pushViewController:photoFeedController animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *cachedHeight = self.cellHeightsByIdentifier[@"strandCell"];
  if (!cachedHeight) {
    DFLargeCardTableViewCell *templateCell = [DFLargeCardTableViewCell cellWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[@"strandCell"] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}


@end
