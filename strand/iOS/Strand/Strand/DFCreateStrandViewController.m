//
//  DFCreateStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandViewController.h"
#import "DFCameraRollSyncManager.h"
#import "DFPeanutSuggestedStrandsAdapter.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutSearchObject.h"
#import "DFPhotoStore.h"
#import "DFGallerySectionHeader.h"
#import "DFCreateStrandTableViewCell.h"
#import "DFPeanutSearchObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFSelectPhotosViewController.h"

@interface DFCreateStrandViewController ()

@property (readonly, nonatomic, retain) DFPeanutSuggestedStrandsAdapter *suggestionsAdapter;
@property (nonatomic, retain) DFPeanutObjectsResponse *response;

@end

@implementation DFCreateStrandViewController
@synthesize suggestionsAdapter = _suggestionsAdapter;


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
       forCellReuseIdentifier:@"cell"];
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


#pragma mark - UITableView Data/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.response.topLevelSectionObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSearchObject *section = self.response.topLevelSectionObjects[indexPath.row];
  DFCreateStrandTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
  
  // Set the header attributes
  cell.locationLabel.text = section.subtitle;
  cell.countLabel.text = [@(section.objects.count) stringValue];
  DFPeanutSearchObject *firstObject = section.objects.firstObject;
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:firstObject.time_taken];
  
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (DFPeanutSearchObject *object in section.objects) {
    if ([object.type isEqual:DFSearchObjectPhoto]) {
      [idsToShow addObject:@(object.id)];

    } else if ([object.type isEqual:DFSearchObjectCluster]) {
      DFPeanutSearchObject *repObject = object.objects.firstObject;
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
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSearchObject *section = self.response.topLevelSectionObjects[indexPath.row];
  DFSelectPhotosViewController *selectController = [[DFSelectPhotosViewController alloc] init];
  selectController.sectionObject = section;
  [self.navigationController pushViewController:selectController animated:YES];
}


#pragma mark - Actions

- (void)sync:(id)sender
{
  [[DFCameraRollSyncManager sharedManager] sync];
}

- (void)updateSuggestions:(id)sender
{
  [self.suggestionsAdapter fetchSuggestedStrandsWithCompletion:^(DFPeanutObjectsResponse *response, NSData *responseHash, NSError *error) {
    if (error) {
      DDLogError(@"%@ error fetching suggested strands:%@", self.class, error);
    } else {
      self.response = response;
      [self.tableView reloadData];
    }
  }];
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (DFPeanutSuggestedStrandsAdapter *)suggestionsAdapter
{
  if (!_suggestionsAdapter) {
    _suggestionsAdapter = [[DFPeanutSuggestedStrandsAdapter alloc] init];
  }
  
  return _suggestionsAdapter;
}


@end
