//
//  DFStrandsFeedViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxViewController.h"
#import "DFPeanutFeedObject.h"
#import "DFInboxTableViewCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFImageStore.h"
#import "DFFeedViewController.h"
#import "DFSelectPhotosViewController.h"
#import "NSString+DFHelpers.h"
#import "DFPeanutStrandFeedAdapter.h"
#import "DFPeanutUserObject.h"
#import "DFCreateStrandViewController.h"
#import "DFNavigationController.h"
#import "DFStrandConstants.h"
#import "MMPopLabel.h"
#import "DFStrandGalleryViewController.h"

@interface DFInboxViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) NSArray *feedObjects;
@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) MMPopLabel *noItemsPopLabel;
@property (nonatomic, retain) NSMutableDictionary *cellTemplatesByIdentifier;

@end

@implementation DFInboxViewController

@synthesize feedAdapter = _feedAdapter;


- (instancetype)init
{
  self = [super init];
  if (self) {
    _cellTemplatesByIdentifier = [NSMutableDictionary new];
    [self initTabBarItemAndNav];
    [self observeNotifications];
  }
  return self;
}

- (void)initTabBarItemAndNav
{
  self.navigationItem.title = @"Inbox";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(refreshFromServer)
                                               name:DFStrandReloadRemoteUIRequestedNotificationName
                                             object:nil];
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
  if (!self.lastResponseHash) {
    [self.refreshControl beginRefreshing];
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
   registerNib:[UINib nibWithNibName:[[DFInboxTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"strandCell"];
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFInboxTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"inviteCell"];
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"unknown"];
}

- (void)configurePopLabel
{
  self.noItemsPopLabel = [MMPopLabel
                          popLabelWithText:@"Tap here to share photos and get started"];
  [self.tabBarController.view addSubview:self.noItemsPopLabel];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Data Fetch

- (void)refreshFromServer
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [self.feedAdapter
   fetchInboxWithCompletion:^(DFPeanutObjectsResponse *response,
                                       NSData *responseHash,
                                       NSError *error) {
     if (!error && ![responseHash isEqual:self.lastResponseHash]) {
       self.lastResponseHash = responseHash;
       dispatch_async(dispatch_get_main_queue(), ^{
         _feedObjects = response.objects;
         [self.tableView reloadData];
       });
     }
     dispatch_async(dispatch_get_main_queue(), ^{
       [self.refreshControl endRefreshing];
       [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
       
       if (response.objects.count == 0 && !error && self.view.window) {
         [self showCreateBalloon];
       }
       
     });
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
  CGFloat height = 44.0;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  DFInboxCellStyle cellStyle = DFInboxCellStyleInvite;
  NSString *cellIdentifier;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cellIdentifier = @"inviteCell";
    cellStyle = DFInboxCellStyleInvite;
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    cellIdentifier = @"strandCell";
    cellStyle = DFInboxCellStyleStrand;
  }
  
  if (cellIdentifier) {
    UITableViewCell *templateCell = self.cellTemplatesByIdentifier[cellIdentifier];
    if (!templateCell) templateCell = [DFInboxTableViewCell createWithStyle:cellStyle];
    self.cellTemplatesByIdentifier[cellIdentifier] = templateCell;
    height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
  }
  
  return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    cell = [self cellForStrandPosts:feedObject];
  } else {
    // we don't know what type this is, show an unknown cell on Dev and make a best effort on prod
    #ifdef DEBUG
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"unknown"];
    cell.contentView.backgroundColor = [UIColor yellowColor];
    cell.textLabel.text = [NSString stringWithFormat:@"Unknown type: %@", feedObject.type];
    #else
    cell = [self cellForAction:feedObject];
    #endif
  }
  
  [cell setNeedsLayout];
  return cell;
}

- (UITableViewCell *)cellForStrandPosts:(DFPeanutFeedObject *)strandPosts
{
  DFInboxTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:@"strandCell"];
  [cell configureForInboxCellStyle:DFInboxCellStyleStrand];
  [self.class resetCell:cell];
  cell.contentView.backgroundColor = [UIColor whiteColor];
  
  // actor/ action
  
  cell.peopleLabel.text = [NSString stringWithFormat:@"with %@", [strandPosts.actorNames
                                                                  componentsJoinedByString:@","]];
  cell.actionTextLabel.text = strandPosts.title;
  cell.titleLabel.text = strandPosts.title;
  
  // time taken
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_stamp
                                                          abbreviate:YES];
  // photo preview
  [self setRemotePhotosForCell:cell
               withStrandPosts:strandPosts
                     maxPhotos:InboxCellMaxPhotos];
  
  return cell;
}

+ (NSString *)firstActorNameForObject:(DFPeanutFeedObject *)object
{
  NSString *name;
  DFPeanutUserObject *firstActor = object.actors.firstObject;
  if (firstActor.id == [[DFUser currentUser] userID]) {
    name = @"You";
  } else {
    name = firstActor.display_name;
  }

  return name;
}

+ (NSString *)multiActorNamesForObject:(DFPeanutFeedObject *)object
{
  NSMutableString *actorsText = [[NSMutableString alloc] initWithString:@""];
  BOOL includeYou = false;
  
  for (NSUInteger i = 0; i < object.actors.count; i++) {
    DFPeanutUserObject *actor = object.actors[i];
    if (actor.id != [[DFUser currentUser] userID]) {
      if (i > 0) [actorsText appendString:@", "];
      [actorsText appendString:[actor display_name]];
    } else {
      includeYou = true;
    }
  }
  if (includeYou) {
    if (object.actors.count > 1) [actorsText appendString:@", "];
    [actorsText appendString:@"You"];
  }

  return actorsText;
}


const NSUInteger inviteRowMaxImages = 3;

- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFInboxTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:@"inviteCell"];
  [cell configureForInboxCellStyle:DFInboxCellStyleInvite];
  [self.class resetCell:cell];
  
  DFPeanutFeedObject *strandPostsObject = inviteObject.objects.firstObject;
  
  cell.actorLabel.text = [self.class multiActorNamesForObject:inviteObject];
  cell.actionTextLabel.text = inviteObject.title;
  cell.titleLabel.text = strandPostsObject.title;
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:inviteObject.time_stamp
                                                          abbreviate:YES];
  cell.peopleLabel.text = [NSString stringWithFormat:@"with %@",
                            [self.class multiActorNamesForObject:strandPostsObject]];
  
  
  [self setRemotePhotosForCell:cell
               withStrandPosts:strandPostsObject
                     maxPhotos:inviteRowMaxImages];
  
  return cell;
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
  
  for (NSUInteger i = 0; i < strandPosts.objects.count && photos.count < maxPhotosToFetch; i++) {
    DFPeanutFeedObject *strandPost = strandPosts.objects[i];
    
    for (NSUInteger j = 0; j < strandPost.objects.count && photos.count < maxPhotosToFetch; j++) {
      DFPeanutFeedObject *object = strandPost.objects[j];
      DFPeanutFeedObject *photoObject;
      if ([object.type isEqual:DFFeedObjectCluster]) {
        photoObject = object.objects.firstObject;
      } else if ([object.type isEqual:DFFeedObjectPhoto]) {
        photoObject = object;
      }
      [photoIDs addObject:@(photoObject.id)];
      [photos addObject:photoObject];
    }
  }
  
  cell.objects = photoIDs;
  for (DFPeanutFeedObject *photoObject in photos) {
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
  DFCreateStrandViewController *createController = [DFCreateStrandViewController sharedViewController];
  DFNavigationController *navController = [[DFNavigationController
                                            alloc] initWithRootViewController:createController];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *invitedStrandPosts = [[feedObject subobjectsOfType:DFFeedObjectStrandPosts]
                                         firstObject];
    DFPeanutFeedObject *suggestedPhotos = [[feedObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                                           firstObject];
    DFSelectPhotosViewController *vc = [[DFSelectPhotosViewController alloc]
                                        initWithTitle:@"Accept Invite"
                                        showsToField:NO
                                        suggestedSectionObject:suggestedPhotos
                                        sharedSectionObject:invitedStrandPosts
                                        inviteObject:feedObject
                                        ];
    [self.navigationController pushViewController:vc animated:YES];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]) {
    [self showStrandPostsObject:feedObject];
  }

  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showStrandPostsObject:(DFPeanutFeedObject *)strandPostsObject
{
  DFStrandGalleryViewController *vc = [[DFStrandGalleryViewController alloc] init];
  vc.strandPosts = strandPostsObject;
  [self.navigationController pushViewController:vc animated:YES];
}


#pragma mark - Network Adapter

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _feedAdapter;
}


@end
