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

@interface DFActivityFeedViewController ()

@property (nonatomic, retain) UIRefreshControl *refreshControl;

@property (nonatomic, retain) NSArray *invitedStrands;
@property (nonatomic, retain) NSArray *regularStrands;


@end

@implementation DFActivityFeedViewController


- (instancetype)init
{
  self = [super initWithFeedType:activityFeed];
  if (self) {
    self.delegate = self;
    [self initTabBarItem];
  }
  return self;
}

- (void)initTabBarItem
{
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

#pragma mark - DFStrandsViewControllerDelegate

- (void)strandsViewControllerUpdatedData:(DFStrandsViewController *)strandsViewController
{
  self.regularStrands = self.strandObjects;
  NSMutableArray *inviteStrands = [NSMutableArray new];
  for (DFPeanutFeedObject *inviteObject in self.inviteObjects) {
    [inviteStrands addObject:inviteObject.objects.firstObject];
  }
  self.invitedStrands = inviteStrands;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (inviteStrands.count > 0) {
      self.tabBarItem.badgeValue = [@(inviteStrands.count) stringValue];
    } else {
      self.tabBarItem.badgeValue = nil;
    }
    [self.tableView reloadData];
  });
}

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController
didFinishServerFetchWithError:(NSError *)error
{
  // Turn off spinner since we successfully did a server fetch
  [self.refreshControl endRefreshing];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return (self.invitedStrands.count > 0) + (self.regularStrands.count > 0);
}

- (NSArray *)strandsForSection:(NSInteger)section
{
  if (section == 0 && self.invitedStrands.count > 0) return self.invitedStrands;
  return self.regularStrands;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self strandsForSection:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *strandObject = [self strandsForSection:indexPath.section][indexPath.row];
  if ([strandObject.type isEqualToString:DFFeedObjectLikeAction]) {
    return ActivityFeedTableViewCellHeight / 2.0;
  }
  return ActivityFeedTableViewCellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  DFPeanutFeedObject *strandObject = [self strandsForSection:indexPath.section][indexPath.row];
  
  DFPeanutFeedObject *inviteObject;

  if (self.invitedStrands.count > 0 && indexPath.section == 0) {
    inviteObject = self.inviteObjects[indexPath.row];
  }
  
  cell = [self cellWithStrandObject:strandObject inviteObject:inviteObject];
  
  [cell setNeedsLayout];
  return cell;
}

- (UITableViewCell *)cellWithStrandObject:(DFPeanutFeedObject *)strandObject
                             inviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFActivityFeedTableViewCell *cell = [self.tableView
                                       dequeueReusableCellWithIdentifier:[[DFActivityFeedTableViewCell class] description]];
  
  
  // actor/ action
  NSArray *actors;
  NSString *action;
  if (inviteObject) {
    actors = inviteObject.actors;
    action = inviteObject.title;
    cell.contentView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.2];
  } else {
    actors = strandObject.actors;
    action = strandObject.title;
    cell.contentView.backgroundColor = [UIColor whiteColor];
  }
  
  NSMutableArray *abbreviations = [NSMutableArray new];
  for (DFPeanutUserObject *actor in actors) {
    NSString *abbreviation = [actor.display_name substringToIndex:1];
    if ([abbreviation isNotEmpty] && [abbreviations indexOfObject:abbreviation] == NSNotFound) {
      [abbreviations addObject:abbreviation];
    }
  }
  
  cell.profilePhotoStackView.abbreviations = abbreviations;
  
  cell.actorLabel.text = [(DFPeanutUserObject *)actors.firstObject display_name];
  cell.actionTextLabel.text = action;
  // time taken
  DFPeanutFeedObject *photoObject = strandObject.objects.firstObject;
  if ([photoObject.type isEqual:DFFeedObjectCluster]) photoObject = photoObject.objects.firstObject;
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter]
                         stringFromDate:photoObject.time_taken];
  // photo preview
  [self setRemotePhotosForCell:cell withSection:strandObject];
  
  return cell;
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


#pragma mark - Table View delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *strandsForSection = [self strandsForSection:indexPath.section];
  if (strandsForSection == self.invitedStrands) {
    DFPeanutFeedObject *inviteObject = self.inviteObjects[indexPath.row];
    DFPeanutFeedObject *invitedStrand = inviteObject.objects.firstObject;
    
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
  } else {
    DFFeedViewController *feedController = [[DFFeedViewController alloc] init];
    feedController.strandToShow = strandsForSection[indexPath.row];
    [self.navigationController pushViewController:feedController animated:YES];
  }
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}



@end
