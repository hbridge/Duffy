//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFPhotoStore.h"
#import "DFSelectablePhotoViewCell.h"
#import "DFPeanutStrandAdapter.h"
#import "SVProgressHUD.h"
#import "DFUploadController.h"

@interface DFSelectPhotosViewController ()

@property (nonatomic, retain) NSArray *photoObjects;
@property (nonatomic, retain) NSMutableArray *selectedPhotoIDs;

@end

@implementation DFSelectPhotosViewController

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    [self configureNavBar];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureCollectionView];
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self action:@selector(donePressed:)];
}

- (void)configureCollectionView
{
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  [self.collectionView registerNib:[UINib nibWithNibName:[DFSelectablePhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  
}

- (void)setSectionObject:(DFPeanutSearchObject *)sectionObject
{
  _sectionObject = sectionObject;
  NSMutableArray *photos = [NSMutableArray new];
  self.selectedPhotoIDs = [NSMutableArray new];
  for (DFPeanutSearchObject *object in sectionObject.enumeratorOfDescendents.allObjects) {
    if ([object.type isEqual:DFSearchObjectPhoto]) {
      [photos addObject:object];
      // select all by default
      [self.selectedPhotoIDs addObject:@(object.id)];
    }
  }
  self.photoObjects = photos;
}

#pragma mark - UICollectionView Data/Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    headerView.titleLabel.text = self.sectionObject.title;
    headerView.subtitleLabel.text = self.sectionObject.subtitle;
    
    
    view = headerView;
  }
  return view;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.photoObjects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFSelectablePhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                         forIndexPath:indexPath];
  
  
  DFPeanutSearchObject *object = self.photoObjects[indexPath.row];
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:object.id];
  
  // show the selected status
  cell.showTickMark = [self.selectedPhotoIDs containsObject:@(object.id)];

  // set the image
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



- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSearchObject *photoObject = self.photoObjects[indexPath.row];
  NSUInteger index = [self.selectedPhotoIDs indexOfObject:@(photoObject.id)];
  if (index != NSNotFound) {
    [self.selectedPhotoIDs removeObjectAtIndex:index];
  } else {
    [self.selectedPhotoIDs addObject:@(photoObject.id)];
  }
  
  DDLogVerbose(@"selectedIndex:%@ photoID:%@ selectedPhotoIDs:%@",
               indexPath.description,
               @(photoObject.id),
               self.selectedPhotoIDs);
  
  [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
  [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
}


#pragma mark - Actions

- (void)donePressed:(id)sender
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.users = @[@([[DFUser currentUser] userID])];
  requestStrand.photos = self.selectedPhotoIDs;
  requestStrand.shared = YES;
  [self setTimesForStrand:requestStrand fromPhotoObjects:self.photoObjects];
  
  
  DFPeanutStrandAdapter *strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  [strandAdapter performRequest:RKRequestMethodPOST
               withPeanutStrand:requestStrand success:^(DFPeanutStrand *peanutStrand) {
                 DDLogInfo(@"%@ successfully created strand: %@", self.class, peanutStrand);
                 [self dismissViewControllerAnimated:YES completion:^{
                   [SVProgressHUD showSuccessWithStatus:@"Success!"];
                 }];
                 [self markPhotosForUpload:peanutStrand.photos];
               } failure:^(NSError *error) {
                 [SVProgressHUD showErrorWithStatus:@"Failed."];
                 DDLogError(@"%@ failed to create strand: %@, error: %@",
                            self.class, requestStrand, error);
               }];
}

- (void)setTimesForStrand:(DFPeanutStrand *)strand fromPhotoObjects:(NSArray *)objects
{
  NSDate *minDateFound;
  NSDate *maxDateFound;
  
  for (DFPeanutSearchObject *object in objects) {
    if (!minDateFound || [object.time_taken compare:minDateFound] == NSOrderedAscending) {
      minDateFound = object.time_taken;
    }
    if (!maxDateFound || [object.time_taken compare:maxDateFound] == NSOrderedDescending) {
      maxDateFound = object.time_taken;
    }
  }
  
  strand.time_started = minDateFound;
  strand.last_photo_time = maxDateFound;
}

- (void)markPhotosForUpload:(NSArray *)photoIDs
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSArray *photos = [[DFPhotoStore sharedStore] photosWithPhotoIDs:photoIDs retainOrder:NO];
    for (DFPhoto *photo in photos) {
      photo.shouldUploadImage = YES;
    }
    [[DFPhotoStore sharedStore] saveContext];
    [[DFUploadController sharedUploadController] uploadPhotos];
  });
}


@end
