//
//  DFCreateStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandViewController.h"
#import "DFCameraRollSyncManager.h"
#import "DFPeanutStrandFeedAdapter.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFGallerySectionHeader.h"
#import "DFCreateStrandTableViewCell.h"
#import "DFPeanutFeedObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFSelectPhotosViewController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFPeanutStrandAdapter.h"
#import "DFImageStore.h"
#import "NSString+DFHelpers.h"
#import "DFStrandConstants.h"

const CGFloat CreateCellWithTitleHeight = 192;
const CGFloat CreateCellTitleHeight = 20;
const CGFloat CreateCellTitleSpacing = 8;


@interface DFCreateStrandViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;

@property (nonatomic, retain) DFPeanutObjectsResponse *suggestedResponse;
@property (nonatomic, retain) NSArray *inviteObjects;

@property (nonatomic, retain) NSData *lastResponseHash;

@end

@implementation DFCreateStrandViewController
@synthesize feedAdapter = _feedAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize strandAdapter = _strandAdapter;
@synthesize showInvites = _showInvites;

static DFCreateStrandViewController *instance;
+ (DFCreateStrandViewController *)sharedViewController
{
  if (!instance) {
    instance = [[DFCreateStrandViewController alloc] init];
  }
  return instance;
}

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _showInvites = NO;
    [self configureNav];
    [self configureTableView];
    [self observeNotifications];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  }
  return self;
}

- (void)configureNav
{
  self.navigationItem.title = @"Start Strand";
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Back"
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
}

- (void)configureTableView
{
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"cellWithTitle"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"cellNoTitle"];
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
  [self.refreshControl beginRefreshing];
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
  [self refreshFromServer];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  if (self.navigationController.isBeingPresented) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancelPressed:)];
  }
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setShowInvites:(BOOL)showInvites
{
  _showInvites = showInvites;
  
  // Redraw the controller since we might have changed what is shown
  [self reloadData];
}


#pragma mark - UITableView Data/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1 + (self.inviteObjects.count > 0 && self.showInvites);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (self.showInvites && self.inviteObjects.count > 0 && section == 0) {
    return @"Invitations";
  }
 
  return @"Start a Strand";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self sectionObjectsForSection:section] count];
}

- (NSArray *)sectionObjectsForSection:(NSUInteger)section
{
  if ([self shouldShowInvites] && section == 0) {
    return self.inviteObjects;
  }
  
  return self.suggestedResponse.topLevelSectionObjects;
}

- (BOOL)shouldShowInvites
{
  if (self.showInvites && self.inviteObjects.count > 0) {
    return YES;
  }
  
  return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section][indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *strandObject = feedObject.objects.firstObject;
    cell = [self cellWithStrandObject:strandObject isInviteCell:YES];
  } else {
    cell = [self cellWithStrandObject:feedObject isInviteCell:NO];
  }
  
  return cell;
}

- (UITableViewCell *)cellWithStrandObject:(DFPeanutFeedObject *)strandObject
                             isInviteCell:(BOOL)isInviteCell
{
  DFCreateStrandTableViewCell *cell;
  if ([strandObject.title isNotEmpty]) {
   cell = [self.tableView dequeueReusableCellWithIdentifier:@"cellWithTitle"];
  } else {
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"cellNoTitle"];
    if (cell.titleLabel.superview) [cell.titleLabel removeFromSuperview];
  }
  
  DFPeanutFeedObject *photoObject = strandObject.objects.firstObject;
  if ([photoObject.type isEqual:DFFeedObjectCluster]) photoObject = photoObject.objects.firstObject;
  
  // Set the header attributes
  cell.titleLabel.text = strandObject.title;
  cell.locationLabel.text = strandObject.subtitle;
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter]
                         stringFromDate:photoObject.time_taken];
  
  if (isInviteCell) {
    [self setRemotePhotosForCell:cell withSection:strandObject];
  } else {
    [self setLocalPhotosForCell:cell section:strandObject];
  }
  
  return cell;
}

- (void)setRemotePhotosForCell:(DFCreateStrandTableViewCell *)cell
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


- (void)setLocalPhotosForCell:(DFCreateStrandTableViewCell *)cell
                      section:(DFPeanutFeedObject *)section
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (DFPeanutFeedObject *object in section.objects) {
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [idsToShow addObject:@(object.id)];
      
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      DFPeanutFeedObject *repObject = object.objects.firstObject;
      [idsToShow addObject:@(repObject.id)];
    }
  }
  
  // Set the images for the collection view
  cell.objects = idsToShow;
  for (NSNumber *photoID in idsToShow) {
    DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:photoID.longLongValue];
    if (photo) {
      [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
        [cell setImage:image forObject:photoID];
      } failureBlock:^(NSError *error) {
        DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
      }];
    }
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section][indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]
      || [feedObject.title isNotEmpty]) return CreateCellWithTitleHeight;
  else return CreateCellWithTitleHeight - CreateCellTitleHeight - CreateCellTitleSpacing;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *feedObjectsForSection = [self sectionObjectsForSection:indexPath.section];
  DFPeanutFeedObject *feedObject = feedObjectsForSection[indexPath.row];
  DFSelectPhotosViewController *selectController;
  if ([feedObject.type isEqualToString:DFFeedObjectInviteStrand]) {
    DFPeanutFeedObject *strandObject = feedObject.objects.firstObject;
    [self.feedAdapter
     fetchSuggestedPhotosForStrand:@(strandObject.id)
     completion:^(DFPeanutObjectsResponse *response, NSData *responseHash, NSError *error) {
       
       dispatch_async(dispatch_get_main_queue(), ^{
         DFPeanutFeedObject *suggestionObject;
         if (!error) {
           suggestionObject = response.objects.firstObject;
         }
         
         // this is an invite, the object that user selected represenets the shared photos
         // don't show the to field
         DFSelectPhotosViewController *selectController = [[DFSelectPhotosViewController alloc]
                             initWithTitle:@"Accept Invite"
                             showsToField:NO
                             suggestedSectionObject:suggestionObject
                             sharedSectionObject:feedObject.objects.firstObject
                                                           inviteObject:feedObject];
         selectController.inviteObject = feedObject;
         [self.navigationController pushViewController:selectController animated:YES];
       });
       
       
     }];
    
  } else {
    // this is creating a new strand, the object they selected is a suggestion
    // we also want to show a to field to invite others
    selectController = [[DFSelectPhotosViewController alloc]
                        initWithTitle:@"Create Strand"
                        showsToField:YES
                        suggestedSectionObject:feedObject
                        sharedSectionObject:nil
                        inviteObject:nil
                        ];
    [self.navigationController pushViewController:selectController animated:YES];
  }
}


#pragma mark - Actions

- (void)sync:(id)sender
{
  [[DFCameraRollSyncManager sharedManager] sync];
}


- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView reloadData];
  });
}

- (void)refreshFromServer
{
  [self.feedAdapter fetchSuggestedStrandsWithCompletion:^(DFPeanutObjectsResponse *response,
                                                          NSData *responseHash,
                                                          NSError *error) {
    if (error) {
      DDLogError(@"%@ error fetching suggested strands:%@", self.class, error);
    } else {
      self.suggestedResponse = response;
      
      if (![responseHash isEqual:self.lastResponseHash]) {
        DDLogDebug(@"New data for suggestions, updating view...");
        [self reloadData];
        self.lastResponseHash = responseHash;
      } else {
        DDLogDebug(@"Got back response for strand suggestions but it was the same");
      }
    }
    
    if (response.objects.count > 0 || error) {
      [self.refreshControl endRefreshing];
    }
  }];
  
  if (self.showInvites) {
    [self.feedAdapter
     fetchInvitedStrandsWithCompletion:^(DFPeanutObjectsResponse *response,
                                         NSData *responseHash,
                                         NSError *error) {
      self.inviteObjects = [response topLevelObjectsOfType:DFFeedObjectInviteStrand];
      [self.tableView reloadData];
    }];
  }
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) {
    _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  }
  
  return _feedAdapter;
}
- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) {
    _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  }
  
  return _inviteAdapter;
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) {
    _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  }
  
  return _strandAdapter;
}

@end
