//
//  DFSingleFriendViewController.m
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandViewController.h"
#import "DFSingleFriendViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFLargeCardTableViewCell.h"
#import "DFFeedViewController.h"
#import "DFPeanutUserObject.h"
#import "DFPeanutFeedObject.h"
#import "DFStrandConstants.h"

@interface DFSingleFriendViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;
@property (nonatomic, retain) DFPeanutUserObject *userToView;
@property (nonatomic, retain) NSArray *strandsToShow;
@property (nonatomic) BOOL useSharedPhotos;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;

@end

@implementation DFSingleFriendViewController


- (instancetype)initWithUser:(DFPeanutUserObject *)userToView withSharedPhotos:(BOOL)useSharedPhotos
{
  self = [super init];
  if (self) {
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
    self.userToView = userToView;
    self.useSharedPhotos = useSharedPhotos;
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self configureTableView];
  [self reloadData];
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


- (void)reloadData
{
  if (self.useSharedPhotos) {
    self.strandsToShow = [self.dataManager publicStrandsWithUser:self.userToView];
  } else {
    self.strandsToShow = [self.dataManager privateStrandsWithUser:self.userToView];
  }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.strandsToShow.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *strandObject = self.strandsToShow[indexPath.row];
  
  DFLargeCardTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"strandCell"];
  [cell configureWithStyle:DFCreateStrandCellStyleSuggestionWithPeople];
  
  [cell configureWithFeedObject:strandObject];
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.useSharedPhotos) {
    DFPeanutFeedObject *strandPosts = self.strandsToShow[indexPath.row];
    
    DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] init];
    photoFeedController.strandPostsObject = strandPosts;
    [self.navigationController pushViewController:photoFeedController animated:YES];
  } else {
    DFPeanutFeedObject *sectionObject = self.strandsToShow[indexPath.row];
    
    DFCreateStrandViewController *createStrandController = [[DFCreateStrandViewController alloc]
                                                            initWithSuggestions:@[sectionObject]];
    [self.navigationController pushViewController:createStrandController animated:YES];
  }
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
