//
//  DFStrandsFeedViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFActivityFeedViewController.h"
#import "DFPeanutFeedObject.h"
#import "DFActivityFeedTableViewCell.h"
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

@interface DFActivityFeedViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) NSArray *feedObjects;
@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) MMPopLabel *noItemsPopLabel;

@end

@implementation DFActivityFeedViewController

@synthesize feedAdapter = _feedAdapter;


- (instancetype)init
{
  self = [super init];
  if (self) {
    [self initTabBarItemAndNav];
  }
  return self;
}

- (void)initTabBarItemAndNav
{
  self.navigationItem.title = @"Activity";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureRefreshControl];
  [self configureTableView];
  [self configurePopLabel];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self refreshFromServer];
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
   registerNib:[UINib nibWithNibName:[[DFActivityFeedTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"collectionCell"];
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFActivityFeedTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"singleCell"];
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
   fetchStrandActivityWithCompletion:^(DFPeanutObjectsResponse *response,
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
       
       if (response.objects.count == 0) {
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
  CGFloat height;
  NSUInteger numRows = 0;
  DFPeanutFeedObject *activityObject = self.feedObjects[indexPath.row];
  if ([activityObject.type isEqualToString:DFFeedObjectLikeAction]
      || [activityObject.type isEqual:DFFeedObjectStrandJoin]) {

    height = ActivityFeedTableViewCellNoCollectionViewHeight;
  } else {
    DFPeanutFeedObject *strandObject = activityObject.objects.firstObject;
    numRows = ceil((float)MIN(4,strandObject.objects.count)/2.0);
    
    height = ActivityFeedTableViewCellNoCollectionViewHeight
    + numRows * ActivtyFeedTableViewCellCollectionViewRowHeight
    + (numRows - 1) * ActivtyFeedTableViewCellCollectionViewRowSeparatorHeight;
  }
  DDLogVerbose(@"IP: %@ is type %@ numRows:%d height :%.01f",
               indexPath,
               activityObject.type,
               (int)numRows,
               height);
  return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPost]) {
    cell = [self cellForStrandPost:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectLikeAction]) {
    cell = [self cellForAction:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandJoin]) {
    cell = [self cellForAction:feedObject];
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

- (UITableViewCell *)cellForStrandPost:(DFPeanutFeedObject *)strandPost
{
  DFPeanutFeedObject *strandObject = strandPost.objects.firstObject;
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:@"collectionCell"];
  if (cell.previewImageView.superview) {
    [cell.previewImageView removeFromSuperview];
  }
  [self.class resetCell:cell];
  cell.contentView.backgroundColor = [UIColor whiteColor];
  
  // actor/ action
  cell.profilePhotoStackView.names = strandPost.actorNames;
  cell.actorLabel.text = [self.class firstActorNameForObject:strandPost];
  cell.actionTextLabel.text = strandPost.title;
  cell.subtitleLabel.text = strandPost.subtitle;
  
  // time taken
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:strandPost.time_stamp
                                                          abbreviate:YES];
  // photo preview
  [self setRemotePhotosForCell:cell withSection:strandObject];
  
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

- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:@"collectionCell"];
  if (cell.previewImageView.superview) {
    [cell.previewImageView removeFromSuperview];
  }
  [self.class resetCell:cell];
  
  DFPeanutFeedObject *strandObject = inviteObject.objects.firstObject;
  cell.contentView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
  cell.profilePhotoStackView.names = inviteObject.actorNames;
  cell.actorLabel.text = [self.class firstActorNameForObject:inviteObject];
  cell.actionTextLabel.text = inviteObject.title;
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:inviteObject.time_stamp
                                                          abbreviate:YES];
  cell.subtitleLabel.text = strandObject.title;

  [self setRemotePhotosForCell:cell withSection:inviteObject.objects.firstObject];
  
  return cell;
}

- (UITableViewCell *)cellForAction:(DFPeanutFeedObject *)actionObject
{
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:@"singleCell"];
  if (cell.collectionView.superview) {
    [cell.collectionView removeFromSuperview];
  }
  
  [self.class resetCell:cell];
  
  cell.contentView.backgroundColor = [UIColor whiteColor];
  
  // actor/ action
  cell.profilePhotoStackView.names = actionObject.actorNames;
  cell.actorLabel.text = [self.class firstActorNameForObject:actionObject];
  cell.actionTextLabel.text = actionObject.title;
  
  //Subtitle (strand name_
  cell.subtitleLabel.text = actionObject.subtitle;
  
  // time taken
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:actionObject.time_stamp
                         abbreviate:YES];
  // photo preview
  [self setRemotePreviewPhotoForCell:cell withFeedObject:actionObject];

  return cell;
}

+ (void)resetCell:(DFActivityFeedTableViewCell *)cell
{
  cell.timeLabel.text = @"T";
  cell.actorLabel.text = @"Actor";
  cell.actionTextLabel.text = @"Action";
  cell.subtitleLabel.text = @"Subtitle";
  cell.objects = @[];
  cell.previewImageView.image = nil;
}

- (void)setRemotePhotosForCell:(DFActivityFeedTableViewCell *)cell
                   withSection:(DFPeanutFeedObject *)section
{
  NSMutableArray *photoIDs = [NSMutableArray new];
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in section.objects) {
    DFPeanutFeedObject *photoObject;
    if ([object.type isEqual:DFFeedObjectCluster]) {
      photoObject = object.objects.firstObject;
    } else if ([object.type isEqual:DFFeedObjectPhoto]) {
      photoObject = object;
    }
    [photoIDs addObject:@(photoObject.id)];
    [photos addObject:photoObject];
  }
  
  cell.objects = photoIDs;
  for (DFPeanutFeedObject *photoObject in photos) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageFull
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       [cell setImage:image forObject:@(photoObject.id)];
     }];
  }
}

- (void)setRemotePreviewPhotoForCell:(DFActivityFeedTableViewCell *)cell
                      withFeedObject:(DFPeanutFeedObject *)object
{
  DFPeanutFeedObject *photoObject = object.objects.firstObject;
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:DFImageThumbnail
   thumbnailPath:photoObject.thumb_image_path
   fullPath:photoObject.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       cell.previewImageView.image = image;
       [cell setNeedsDisplay];
     });
   }];
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
    DFPeanutFeedObject *invitedStrand = [[feedObject subobjectsOfType:DFFeedObjectSection]
                                         firstObject];
    DFPeanutFeedObject *suggestedPhotos = [[feedObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                                           firstObject];
    DFSelectPhotosViewController *vc = [[DFSelectPhotosViewController alloc]
                                        initWithTitle:@"Accept Invite"
                                        showsToField:NO
                                        suggestedSectionObject:suggestedPhotos
                                        sharedSectionObject:invitedStrand
                                        inviteObject:feedObject
                                        ];
    [self.navigationController pushViewController:vc animated:YES];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPost]) {
    [self showStrandForContainingObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectLikeAction]) {
    // the like action has a photo as subobject, need to handle

  } else if ([feedObject.type isEqual:DFFeedObjectStrandJoin]) {
    [self showStrandForContainingObject:feedObject];
  }

  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showStrandForContainingObject:(DFPeanutFeedObject *)feedObject
{
  DFPeanutFeedObject *strandObject = feedObject.objects.firstObject;
  DFFeedViewController *feedController = [[DFFeedViewController alloc] init];
  feedController.strandObjects = @[strandObject];
  [self.navigationController pushViewController:feedController animated:YES];

}


#pragma mark - Network Adapter

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _feedAdapter;
}


@end
