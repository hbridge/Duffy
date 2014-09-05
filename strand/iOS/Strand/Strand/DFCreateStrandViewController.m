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
#import "DFStrandInviteTableViewCell.h"

@interface DFCreateStrandViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;

@property (nonatomic, retain) DFPeanutObjectsResponse *suggestedResponse;
@property (nonatomic, retain) NSArray *inviteObjects;

@end

@implementation DFCreateStrandViewController
@synthesize feedAdapter = _feedAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize strandAdapter = _strandAdapter;

- (instancetype)initWithShowInvites:(BOOL)showInvites
{
  self = [self init];
  if (self) {
    _showInvites = showInvites;
  }
  return self;
}

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    [self configureNav];
    [self configureTableView];
  }
  return self;
}

- (void)configureNav
{
  self.navigationItem.title = @"Create Strand";
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                           target:self
                                           action:@selector(cancelPressed:)];
  
  
  
  self.navigationItem.rightBarButtonItems =
  @[[[UIBarButtonItem alloc]
     initWithTitle:@"Sync"
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(sync:)],
    [[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
     target:self
     action:@selector(updateSuggestions:)],
    ];
  
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Back"
                                           style:UIBarButtonItemStylePlain
                                           target:self
                                           action:nil];
}

- (void)configureTableView
{
  [self.tableView registerNib:[UINib nibWithNibName:@"DFCreateStrandTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"suggestion"];

  [self.tableView registerNib:[UINib nibWithNibName:@"DFStrandInviteTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"invite"];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self updateSuggestions:self];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setShowInvites:(BOOL)showInvites
{
  [self updateSuggestions:self];
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
    cell = [self cellWithObject:strandObject isInviteCell:YES];
  } else {
    cell = [self cellWithObject:feedObject isInviteCell:NO];
  }
  
  return cell;
}

- (UITableViewCell *)cellWithObject:(DFPeanutFeedObject *)suggestion
                             isInviteCell:(BOOL)isInviteCell
{
  DFCreateStrandTableViewCell *cell;
  if (isInviteCell) {
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"invite"];
  } else {
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"suggestion"];
  }
  
  // Set the header attributes
  cell.locationLabel.text = suggestion.subtitle;
  cell.countLabel.text = [@(suggestion.objects.count) stringValue];
  DFPeanutFeedObject *firstObject = suggestion.objects.firstObject;
  cell.timeLabel.text = [[NSDateFormatter HumanDateFormatter] stringFromDate:firstObject.time_taken];
  
  if (isInviteCell) {
    [self setRemotePhotosForCell:cell withSection:suggestion];
    [(DFStrandInviteTableViewCell *)cell titleLabel].text = suggestion.title;
  } else {
    [self setLocalPhotosForCell:cell section:suggestion];
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
  if ([self shouldShowInvites] && indexPath.section == 0) {
    return 189.0;
  }
  
  return 170.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *feedObjectsForSection = [self sectionObjectsForSection:indexPath.section];
  DFPeanutFeedObject *feedObject = feedObjectsForSection[indexPath.row];
  DFSelectPhotosViewController *selectController;
  if ([feedObject.type isEqualToString:DFFeedObjectInviteStrand]) {
    [self.feedAdapter
     fetchSuggestedPhotosForStrand:@(feedObject.id)
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
                             sharedSectionObject:feedObject.objects.firstObject];
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
                        sharedSectionObject:nil];
    [self.navigationController pushViewController:selectController animated:YES];
  }
}


#pragma mark - Actions

- (void)sync:(id)sender
{
  [[DFCameraRollSyncManager sharedManager] sync];
}

- (void)updateSuggestions:(id)sender
{
  [self.feedAdapter fetchSuggestedStrandsWithCompletion:^(DFPeanutObjectsResponse *response, NSData *responseHash, NSError *error) {
    if (error) {
      DDLogError(@"%@ error fetching suggested strands:%@", self.class, error);
    } else {
      self.suggestedResponse = response;
      [self.tableView reloadData];
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
