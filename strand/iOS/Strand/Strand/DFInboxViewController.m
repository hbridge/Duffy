//
//  DFStrandsFeedViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxViewController.h"

#import "MMPopLabel.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "SVProgressHUD.h"

#import "NSString+DFHelpers.h"

#import "DFAcceptInviteViewController.h"
#import "DFFeedViewController.h"
#import "DFImageStore.h"
#import "DFPeanutFeedDataManager.h"
#import "DFInboxTableViewCell.h"
#import "DFCardTableViewCell.h"
#import "DFNavigationController.h"
#import "DFPeanutFeedObject.h"
#import "DFPeanutFeedAdapter.h"
#import "DFPeanutUserObject.h"
#import "DFSelectPhotosController.h"
#import "DFStrandConstants.h"
#import "DFStrandSuggestionsViewController.h"
#import "DFStrandGalleryTitleView.h"
#import "DFStrandGalleryViewController.h"
#import "DFFeedViewController.h"


@interface DFInboxViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *manager;
@property (readonly, nonatomic, retain) NSArray *feedObjects;
@property (nonatomic, retain) MMPopLabel *noItemsPopLabel;
@property (nonatomic, retain) NSTimer *refreshTimer;
@property (nonatomic, retain) NSMutableDictionary *cellTemplatesByIdentifier;
@property (nonatomic, retain) UILabel *noPhotosLabel;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;

@end

@implementation DFInboxViewController


- (instancetype)init
{
  self = [super init];
  if (self) {
    _cellTemplatesByIdentifier = [NSMutableDictionary new];
    [self initTabBarItemAndNav];
    [self observeNotifications];
    self.manager = [DFPeanutFeedDataManager sharedManager];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)initTabBarItemAndNav
{
  self.navigationItem.title = @"Strand";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createButtonPressed:)];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureRefreshControl];
  [self configureTableView];
  [self configurePopLabel];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self refreshFromServer];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (![self.manager hasData] && ![self.manager isRefreshingInbox]) {
    [self.refreshControl beginRefreshing];
    [self refreshFromServer];
  }
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [self.noItemsPopLabel dismiss];
}

- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

- (void)configureTableView
{
  [self.tableView
   registerNib:[UINib nibWithNibName:@"DFSmallCardTableViewCell" bundle:nil]
   forCellReuseIdentifier:@"inviteCell"];
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFCardTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"strandCell"];
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"unknown"];
}

- (void)configurePopLabel
{
  self.noItemsPopLabel = [MMPopLabel
                          popLabelWithText:@"Tap here to swap photos"];
  [self.tabBarController.view addSubview:self.noItemsPopLabel];
  
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Data Fetch

- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _feedObjects = [self.manager publicStrands];
    [self.tableView reloadData];
    
    if (self.feedObjects.count == 0) {
      self.noPhotosLabel = [[UILabel alloc] init];
      self.noPhotosLabel.font = [UIFont systemFontOfSize:20.0];
      self.noPhotosLabel.textColor = [UIColor darkGrayColor];
      self.noPhotosLabel.text = @"No Photos Swapped";
      [self.noPhotosLabel sizeToFit];
      [self.view addSubview:self.noPhotosLabel];
      CGRect frame = self.noPhotosLabel.frame;
      frame.origin.x = self.view.frame.size.width / 2.0 - frame.size.width / 2.0;
      frame.origin.y = self.tableView.rowHeight /2.0 - frame.size.height / 2.0;
      self.noPhotosLabel.frame = frame;
    } else {
      [self.noPhotosLabel removeFromSuperview];
      self.noPhotosLabel = nil;
    }
  });
}

- (void)refreshFromServer
{
  [self.manager refreshInboxFromServer:^{
    [self.refreshControl endRefreshing];
  }];
}

- (void)showCreateBalloon
{
  //create a view over the top portion of the create tab
  CGFloat dummyWidth = self.tabBarController.tabBar.frame.size.width / 3.0;
  CGFloat dummyHeight = self.tabBarController.tabBar.frame.size.height / 2.0;
  UIView *dummyView = [[UIView alloc]
                       initWithFrame:
                       CGRectMake(CGRectGetMidX(self.tabBarController.view.frame) - dummyWidth / 2.0,
                                  CGRectGetMaxY(self.tabBarController.view.frame) -
                                  self.tabBarController.tabBar.frame.size.height,
                                  dummyWidth,
                                  dummyHeight)];
  dummyView.backgroundColor = [UIColor clearColor];
  [self.tabBarController.view insertSubview:dummyView belowSubview:self.tabBarController.tabBar];
  [self.noItemsPopLabel popAtView:dummyView animatePopLabel:YES animateTargetView:NO];
  [dummyView removeFromSuperview];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.feedObjects.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  NSString *cellIdentifier;
  DFCardCellStyle style = DFCardCellStyleSuggestionWithPeople;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cellIdentifier = @"inviteCell";
    style = DFCardCellStyleInvite | DFCardCellStyleSmall;
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]){
    style = DFCardCellStyleSuggestionWithPeople;
    cellIdentifier = @"strandCell";
  }

  NSNumber *cachedHeight = self.cellHeightsByIdentifier[cellIdentifier];
  if (!cachedHeight) {
    DFCardTableViewCell *templateCell = [DFCardTableViewCell cellWithStyle:style];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[cellIdentifier] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]){
    cell = [self cellForStrandObject:feedObject];
  }
  
  if (!cell) [NSException raise:@"Cell nil" format:@""];
  
  return cell;
}


- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFCardTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"inviteCell"];
  [cell configureWithStyle:DFCardCellStyleSmall | DFCardCellStyleInvite];
  
  [cell configureWithFeedObject:inviteObject];
  return cell;
}

- (UITableViewCell *)cellForStrandObject:(DFPeanutFeedObject *)strandObject
{
  DFCardTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"strandCell"];
  DDLogDebug(@"DFCardCellStyleSmall: %@", binaryStringFromInteger(DFCardCellStyleSmall));

  DDLogDebug(@"DFCardCellStyleSuggestionWithPeople: %@", binaryStringFromInteger(DFCardCellStyleSuggestionWithPeople));
  [cell configureWithStyle:DFCardCellStyleSuggestionWithPeople];
  
  [cell configureWithFeedObject:strandObject];
  return cell;
}

NSString * binaryStringFromInteger( NSInteger  number )
{
  NSMutableString * string = [[NSMutableString alloc] init];
  
  int spacing = pow( 2, 3 );
  int width = ( sizeof( number ) ) * spacing;
  int binaryDigit = 0;
  NSInteger integer = number;
  
  while( binaryDigit < width )
  {
    binaryDigit++;
    
    [string insertString:( (integer & 1) ? @"1" : @"0" )atIndex:0];
    
    if( binaryDigit % spacing == 0 && binaryDigit != width )
    {
      [string insertString:@" " atIndex:0];
    }
    
    integer = integer >> 1;
  }
  
  return string;
}

+ (void)resetCell:(DFInboxTableViewCell *)cell
{
  cell.timeLabel.text = @"T";
  cell.actorLabel.text = @"Actor";
  cell.actionTextLabel.text = @"Action";
  cell.titleLabel.text = @"Subtitle";
  cell.peopleLabel.text = @"People";
  cell.objects = @[];
}

- (void)setRemotePhotosForCell:(DFInboxTableViewCell *)cell
                   withStrandPosts:(DFPeanutFeedObject *)strandPosts
                     maxPhotos:(NSUInteger)maxPhotosToFetch
{
  NSMutableArray *photoIDs = [NSMutableArray new];
  NSMutableArray *photos = [NSMutableArray new];
  
  for (NSUInteger i = 0; i < strandPosts.objects.count; i++) {
    DFPeanutFeedObject *strandPost = strandPosts.objects[i];
    
    for (NSUInteger j = 0; j < strandPost.objects.count; j++) {
      DFPeanutFeedObject *object = strandPost.objects[j];
      DFPeanutFeedObject *photoObject;
      if ([object.type isEqual:DFFeedObjectCluster]) {
        photoObject = object.objects.firstObject;
      } else if ([object.type isEqual:DFFeedObjectPhoto]) {
        photoObject = object;
      }
      if (photoObject) {
        [photoIDs addObject:@(photoObject.id)];
        [photos addObject:photoObject];
      }
    }
  }
  
  cell.objects = photoIDs;
  for (NSUInteger i = 0; i < MIN(photos.count, maxPhotosToFetch); i++) {
    DFPeanutFeedObject *photoObject = photos[i];
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageThumbnail
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       [cell setImage:image forObject:@(photoObject.id)];
     }];
  }
}


#pragma mark - Table View delegate

- (void)createButtonPressed:(id)sender
{
  DFStrandSuggestionsViewController *createController = [DFStrandSuggestionsViewController sharedViewController];
  DFNavigationController *navController = [[DFNavigationController
                                            alloc] initWithRootViewController:createController];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  
  DFFeedViewController *feedViewController = [[DFFeedViewController alloc] initWithFeedObject:feedObject];
  [self.navigationController pushViewController:feedViewController animated:YES];
}

- (void)showStrandPostsForStrandID:(DFStrandIDType)strandID completion:(void(^)(void))completion
{
  DDLogInfo(@"%@ showStrandPostsForStrandID called for %@ requesting refresh", self.class, @(strandID));
  [self.manager refreshInboxFromServer:^{
    DDLogInfo(@"%@ showStrandPostsForStrandID for %@ refresh callback", self.class, @(strandID));
    DFPeanutFeedObject *strandPostsObject;
    _feedObjects = [self.manager publicStrands];
    for (DFPeanutFeedObject *object in self.feedObjects) {
      if (object.id == strandID) {
        // the strand is still in the invites section, return
        if ([object.type isEqual:DFFeedObjectStrandPosts]) {
          strandPostsObject = object;
          break;
        } else {
          DDLogError(@"%@ showStrandPostsForStrandID: object.type = %@", self.class, object.type);
        }
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (strandPostsObject) {
        DDLogInfo(@"%@ showing strand posts with id%lu",
                  self.class,
                  (long)strandID);
        DFStrandGalleryViewController *vc = [[DFStrandGalleryViewController alloc] init];
        vc.strandPosts = strandPostsObject;
        [self.navigationController setViewControllers:@[self, vc] animated:YES];
        
      } else {
        [self.navigationController setViewControllers:@[self]];
        DDLogError(@"%@ got a request to show strand with id:%lu but none loaded with that ID",
                   self.class,
                   (long)strandID);
      }
      completion();
    });
  }];
}


@end
