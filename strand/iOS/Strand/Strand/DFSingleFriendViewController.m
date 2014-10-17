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
#import "DFCardTableViewCell.h"
#import "DFFeedViewController.h"
#import "DFPeanutUserObject.h"
#import "DFPeanutFeedObject.h"
#import "DFStrandConstants.h"
#import "DFNoTableItemsLabel.h"

@interface DFSingleFriendViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;
@property (nonatomic, retain) DFPeanutUserObject *userToView;
@property (nonatomic, retain) NSArray *strandsToShow;
@property (nonatomic) BOOL useSharedPhotos;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;
@property (nonatomic, retain) UILabel *noResultsLabel;

@end

@implementation DFSingleFriendViewController


- (instancetype)initWithUser:(DFPeanutUserObject *)userToView withSharedPhotos:(BOOL)useSharedPhotos
{
  self = [super init];
  if (self) {
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
    self.userToView = userToView;
    self.useSharedPhotos = useSharedPhotos;
    [self observeNotifications];
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
  [self configureNavBar];
  [self reloadData];
  [self configureNoResultsLabel];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

NSString *const PublicPhotosCellId = @"publicPhotosCell";
NSString *const PrivatePhotosCellId = @"privatePhotosCell";

- (void)configureTableView
{
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFCardTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:PublicPhotosCellId];
  [self.tableView
   registerNib:[UINib nibWithNibName:@"DFSmallCardTableViewCell" bundle:nil]
  forCellReuseIdentifier:PrivatePhotosCellId];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)configureNoResultsLabel
{
  if (!self.noResultsLabel && self.tableView) {
    self.noResultsLabel = [[DFNoTableItemsLabel alloc] initWithSuperView:self.tableView];
    self.noResultsLabel.text = @"No Photos";
  }
  
  if (self.strandsToShow.count == 0) {
    self.noResultsLabel.hidden = NO;
  } else {
    self.noResultsLabel.hidden = YES;
  }
}


- (void)reloadData
{
  if (self.useSharedPhotos) {
    self.strandsToShow = [self.dataManager publicStrandsWithUser:self.userToView];
  } else {
    self.strandsToShow = [self.dataManager privateStrandsWithUser:self.userToView];
  }
  
  [self configureTableView];
  [self.tableView reloadData];
}

- (void)configureNavBar
{
  self.navigationItem.title = self.userToView.display_name;
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
  
  DFCardTableViewCell *cell;
  
  if (self.useSharedPhotos) {
    cell = [tableView dequeueReusableCellWithIdentifier:PublicPhotosCellId];
    [cell configureWithStyle:DFCardCellStyleShared];
  } else {
    cell = [tableView dequeueReusableCellWithIdentifier:PrivatePhotosCellId];
    [cell configureWithStyle:DFCardCellStyleSuggestionWithPeople | DFCardCellStyleSmall];
  }
  
  [cell configureWithFeedObject:strandObject];
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.useSharedPhotos) {
    DFPeanutFeedObject *strandPosts = self.strandsToShow[indexPath.row];
    
    DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] initWithFeedObject:strandPosts];
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
  NSString *identifier;
  DFCardCellStyle style;
  if (self.useSharedPhotos) {
    identifier = PublicPhotosCellId;
    style = DFCardCellStyleSuggestionWithPeople;
  } else {
    identifier = PrivatePhotosCellId;
    style = DFCardCellStyleSuggestionWithPeople | DFCardCellStyleSmall;
  }
  NSNumber *cachedHeight = self.cellHeightsByIdentifier[identifier];
  if (!cachedHeight) {
    DFCardTableViewCell *templateCell = [DFCardTableViewCell cellWithStyle:style];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[identifier] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}


@end
