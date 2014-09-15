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

@interface DFActivityFeedViewController ()

@property (nonatomic, retain) UIRefreshControl *refreshControl;

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) NSArray *feedObjects;

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
}

- (void)viewDidAppear:(BOOL)animated
{
  [self reloadData];
}

- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(reloadFeed)
                forControlEvents:UIControlEventValueChanged];
  [self.tableView addSubview:self.refreshControl];
  
//  UITableViewController *tableViewController = [[UITableViewController alloc] init];
//  tableViewController.tableView = self.tableView;
//  tableViewController.refreshControl = self.refreshControl;
}

- (void)configureTableView
{
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFActivityFeedTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:[[DFActivityFeedTableViewCell class] description]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Data Fetch

- (void)reloadData
{
  [self.feedAdapter
   fetchStrandActivityWithCompletion:^(DFPeanutObjectsResponse *response,
                                       NSData *responseHash,
                                       NSError *error) {
     if (!error) {
       dispatch_async(dispatch_get_main_queue(), ^{
         _feedObjects = response.objects;
         [self.tableView reloadData];
       });
     }
   }];
}


#pragma mark - DFStrandsViewControllerDelegate

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController
didFinishServerFetchWithError:(NSError *)error
{
  // Turn off spinner since we successfully did a server fetch
  [self.refreshControl endRefreshing];
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
  DFPeanutFeedObject *strandObject = self.feedObjects[indexPath.row];
  if ([strandObject.type isEqualToString:DFFeedObjectLikeAction]) {
    return ActivityFeedTableViewCellNoCollectionViewHeight;
  }
  return ActivityFeedTableViewCellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    cell = [self cellForStrandObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectLikeAction]) {
    cell = [self cellForAction:feedObject];
  }
  
  
  
  [cell setNeedsLayout];
  return cell;
}

- (UITableViewCell *)cellForStrandObject:(DFPeanutFeedObject *)strandObject
{
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:[[DFActivityFeedTableViewCell class] description]];
  [self.class resetCell:cell];
  cell.contentView.backgroundColor = [UIColor whiteColor];
  
  // actor/ action
  cell.profilePhotoStackView.abbreviations = strandObject.actorAbbreviations;
  cell.actorLabel.text = [self.class firstActorNameForObject:strandObject];
  cell.actionTextLabel.text = strandObject.title;
  
  // time taken
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter]
                         stringFromDate:strandObject.time_stamp];
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
                                       dequeueReusableCellWithIdentifier:[[DFActivityFeedTableViewCell class] description]];
  [self.class resetCell:cell];
  cell.contentView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.2];
  cell.profilePhotoStackView.abbreviations = inviteObject.actorAbbreviations;
  cell.actorLabel.text = [self.class firstActorNameForObject:inviteObject];
  cell.actionTextLabel.text = inviteObject.title;
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter]
                         stringFromDate:inviteObject.time_stamp];
  [self setRemotePhotosForCell:cell withSection:inviteObject.objects.firstObject];
  
  return cell;
}

- (UITableViewCell *)cellForAction:(DFPeanutFeedObject *)actionObject
{
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:[[DFActivityFeedTableViewCell class] description]];
  [self.class resetCell:cell];
  
  cell.contentView.backgroundColor = [UIColor whiteColor];
  
  // actor/ action
  cell.profilePhotoStackView.abbreviations = actionObject.actorAbbreviations;
  cell.actorLabel.text = [self.class firstActorNameForObject:actionObject];
  cell.actionTextLabel.text = actionObject.title;
  
  // time taken
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter]
                         stringFromDate:actionObject.time_stamp];
  // photo preview
  [self setRemotePreviewPhotoForCell:cell withFeedObject:actionObject];

  return cell;
}

+ (void)resetCell:(DFActivityFeedTableViewCell *)cell
{
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
     preferredType:DFImageThumbnail
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
  DFCreateStrandViewController *createController = [[DFCreateStrandViewController alloc]
                                                    initWithShowInvites:YES];
  createController.showInvites = YES;
  DFNavigationController *navController = [[DFNavigationController
                                            alloc] initWithRootViewController:createController];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *invitedStrand = feedObject.objects.firstObject;
    DFSelectPhotosViewController *vc = [[DFSelectPhotosViewController alloc]
                                        initWithTitle:@"Accept Invite"
                                        showsToField:NO
                                        suggestedSectionObject:nil
                                        sharedSectionObject:invitedStrand];
    
    
    DFPeanutStrandFeedAdapter *feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
    [feedAdapter
     fetchSuggestedPhotosForStrand:@(invitedStrand.id)
     completion:^(DFPeanutObjectsResponse *response, NSData *responseHash, NSError *error) {
       if (!error) {
         vc.suggestedSectionObject = response.objects.firstObject;
       }
     }];
    
    [self.navigationController pushViewController:vc animated:YES];
  } else if ([feedObject.type isEqual:DFFeedObjectSection]) {
    DFFeedViewController *feedController = [[DFFeedViewController alloc] init];
    feedController.strandToShow = feedObject;
    [self.navigationController pushViewController:feedController animated:YES];
  } else if ([feedObject.type isEqual:DFFeedObjectLikeAction]) {
  
  }

  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark - Network Adapter

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _feedAdapter;
}


@end
