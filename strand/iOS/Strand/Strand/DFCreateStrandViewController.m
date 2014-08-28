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

static const CGFloat SectionHeaderWidth = 320;
static const CGFloat SectionHeaderHeight = 54;

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
  }
  return self;
}

- (void)configureNav
{
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
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  [self.collectionView registerNib:[UINib nibWithNibName:[DFPhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


#pragma mark - UICollectionView Data/Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.response.topLevelSectionObjects.count;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    DFPeanutSearchObject *sectionObject = self.response.topLevelSectionObjects[indexPath.section];
    headerView.titleLabel.text = sectionObject.title;
    headerView.subtitleLabel.text = sectionObject.subtitle;
    
    
    view = headerView;
  }
  return view;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  NSArray *objects = [self.response.topLevelSectionObjects[section] objects];
  return objects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                         forIndexPath:indexPath];
  
  NSArray *sectionObjects = [self.response.topLevelSectionObjects[indexPath.section] objects];
  DFPeanutSearchObject *object = sectionObjects[indexPath.row];
  if ([object.type isEqual:DFSearchObjectCluster]) object = object.objects.firstObject;
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:object.id];
  
  cell.imageView.image = nil;
  [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
    //if ([self.collectionView.visibleCells containsObject:cell]) {
      cell.imageView.image = image;
      [cell setNeedsLayout];
    //}
  } failureBlock:^(NSError *error) {
    DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
  }];
  
  return cell;
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
      [self.collectionView reloadData];
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
