//
//  DFGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAllStrandsGalleryViewController.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStackCell.h"
#import "DFPhoto.h"
#import "DFImageStore.h"
#import "DFNavigationController.h"
#import "DFSettingsViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFFeedViewController.h"
#import "DFAnalytics.h"
#import "DFGalleryCollectionViewFlowLayout.h"
#import "NSString+DFHelpers.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"


static const CGFloat ItemSize = 105;
static const CGFloat ItemSpacing = 2.5;

@interface DFAllStrandsGalleryViewController ()

@property (nonatomic, retain) DFGalleryCollectionViewFlowLayout *flowLayout;

@end

@implementation DFAllStrandsGalleryViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.delegate = self;
    [self initNavigationAndTab];
  }
  return self;
}

- (void)initNavigationAndTab
{
  self.navigationItem.title = @"Strands";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/GalleryBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/GalleryBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.flowLayout = [[DFGalleryCollectionViewFlowLayout alloc] init];
  self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame
                                           collectionViewLayout:self.flowLayout];
  [self.view addSubview:self.collectionView];
  
  CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;
  self.collectionView.contentInset = UIEdgeInsetsMake(0,
                                                      0,
                                                      tabBarHeight * 2,
                                                      0);
  [self configureCollectionView];
  
}

- (void)configureCollectionView
{
  self.collectionView.dataSource = self;
  self.collectionView.delegate = self;
  self.collectionView.scrollsToTop = YES;
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"photoCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"clusterCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFLockedPhotoViewCell" bundle:nil]
       forCellWithReuseIdentifier:@"lockedCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionFooter" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footerView"];
  
  
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  self.flowLayout.footerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionFooterHeight);
  self.flowLayout.itemSize = CGSizeMake(ItemSize, ItemSize);
  self.flowLayout.minimumInteritemSpacing = ItemSpacing;
  self.flowLayout.minimumLineSpacing = ItemSpacing;

  
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(reloadFeed)
                forControlEvents:UIControlEventValueChanged];
  [self.collectionView addSubview:self.refreshControl];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)strandsViewControllerUpdatedData:(DFStrandsViewController *)strandsViewController
{
[self.collectionView reloadData];
}

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController didFinishServerFetchWithError:error
{
  [self.refreshControl endRefreshing];
}



# pragma mark - Collection View Datasource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.strandObjects.count;
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    
    DFPeanutFeedObject *sectionObject = [self sectionObjectForUploadedSection:indexPath.section];
    headerView.titleLabel.text = sectionObject.title;
    headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:sectionObject.time_taken
                                                                  abbreviate:YES];
    headerView.profilePhotoStackView.names = sectionObject.actorNames;
    
    
    view = headerView;
  } else if (kind == UICollectionElementKindSectionFooter) {
    view = [self.collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                   withReuseIdentifier:@"footerView"
                                                          forIndexPath:indexPath];
  }
  
  return view;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  DFPeanutFeedObject *sectionObject = [self sectionObjectForUploadedSection:section];
  
  NSArray *items = sectionObject.objects;
  return items.count;
}

- (DFPeanutFeedObject *)sectionObjectForUploadedSection:(NSUInteger)tableSection
{
  return self.strandObjects[tableSection];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutFeedObject *section = [self sectionObjectForUploadedSection:indexPath.section];
  NSArray *itemsForSection = section.objects;
  DFPeanutFeedObject *object = itemsForSection[indexPath.row];
  
  if ([section isLockedSection]) {
    cell = [self cellForLockedSection:section indexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectPhoto]) {
    cell = [self cellForPhoto:object indexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectCluster]) {
    cell = [self cellForCluster:object indexPath:indexPath];
  } else {
    // we don't know what type this is, show an unknown cell on Dev and make a best effort on prod
    cell = [self cellForUnknownObject:section atIndexPath:indexPath];
  }
  
  [cell setNeedsLayout];
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return CGSizeMake(ItemSize, ItemSize);
}

- (UICollectionViewCell *)cellForUnknownObject:(DFPeanutFeedObject *)object atIndexPath:(NSIndexPath *)indexPath
{
  #ifdef DEBUG
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell"
                                                                         forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.backgroundColor = [UIColor yellowColor];
  #else
  //assume it's a regular photo
  UICollectionViewCell *cell = [self cellForPhoto:object indexPath:indexPath];
  #endif
  return cell;
}

- (UICollectionViewCell *)cellForUploadAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  
  DFPhoto *firstPhoto = self.uploadingPhotos.firstObject;
  [firstPhoto.asset loadUIImageForThumbnail:^(UIImage *image) {
    if ([self.collectionView.visibleCells containsObject:cell]) {
      cell.imageView.image = image;

      [cell setNeedsLayout];
    }
  } failureBlock:^(NSError *error) {
    cell.imageView.image = [UIImage imageNamed:@"Assets/Icons/MissingImage320"];
    [cell setNeedsLayout];
    DDLogError(@"Error loading thumbnail for uploading asset.");
  }];
  
  return cell;
}

- (UICollectionViewCell *)cellForLockedSection:(DFPeanutFeedObject *)section
                                     indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *lockedCell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"lockedCell"
                                                                               forIndexPath:indexPath];
  lockedCell.imageView.image = nil;

  DFPeanutFeedObject *object = section.objects[indexPath.row];
  [[DFImageStore sharedStore]
   imageForID:object.id
   preferredType:DFImageThumbnail
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:lockedCell]) return;
       lockedCell.imageView.image = image;
       [lockedCell setNeedsLayout];
     });
   }];

  return lockedCell;
}

- (UICollectionViewCell *)cellForPhoto:(DFPeanutFeedObject *)photoObject
                             indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  
  NSArray *likeActions = [photoObject actionsOfType:DFPeanutActionFavorite forUser:0];
  cell.likeIconImageView.hidden = (likeActions.count <= 0);
  DFImageType preferredType = DFImageThumbnail;
  
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:preferredType
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       if
         (image) cell.imageView.image = image;
       else
         cell.imageView.image = [UIImage imageNamed:@"Assets/Icons/MissingImage320"];
       [cell setNeedsLayout];
     });
   }];
  
  return cell;
}

- (UICollectionViewCell *)cellForCluster:(DFPeanutFeedObject *)clusterObject
                               indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell"
                                                                         forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.likeIconImageView.hidden = YES;
  for (DFPeanutFeedObject *object in clusterObject.objects) {
    if ([[object actionsOfType:DFPeanutActionFavorite forUser:0] count] > 0) {
      cell.likeIconImageView.hidden = NO;
      break;
    }
  }
  
  DFPeanutFeedObject *firstObject = (DFPeanutFeedObject *)clusterObject.objects.firstObject;
  
  [[DFImageStore sharedStore]
   imageForID:firstObject.id
   preferredType:DFImageThumbnail
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       cell.imageView.image = image;
       [cell setNeedsLayout];
     });
   }];

  return cell;
}

#pragma mark - Action Handlers

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoIDType photoID = 0;
  DFPeanutFeedObject *section = [self sectionObjectForUploadedSection:indexPath.section];
  DFPeanutFeedObject *object = section.objects[indexPath.row];
  if ([object.type isEqualToString:DFFeedObjectPhoto]) {
    photoID = object.id;
  } else if ([object.type isEqualToString:DFFeedObjectCluster]) {
    photoID = ((DFPeanutFeedObject *)object.objects.firstObject).id;
  }
  
  DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] initWithFeedObject:section];
  [self.navigationController pushViewController:photoFeedController animated:YES];
  dispatch_async(dispatch_get_main_queue(), ^{
    [photoFeedController showPhoto:photoID animated:NO];
  });
}


- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *indexPath = self.indexPathsByID[@(photoId)];
    
    if (indexPath) {
      if ([[self sectionObjectForUploadedSection:indexPath.section] isLockedSection]) {
        indexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
      }
      
      // set isViewTransitioning to prevent the nav bar from disappearing from the scroll
      [self.collectionView scrollToItemAtIndexPath:indexPath
                                  atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                          animated:animated
       ];
      
      // this tweak is gross but makes for less text from the last section overlapped under the header
      self.collectionView.contentOffset = CGPointMake(self.collectionView.contentOffset.x,
                                                 self.collectionView.contentOffset.y + 10);

      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DFPhotoViewCell *cell = (DFPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
       
        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.keyPath = @"transform";
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        animation.autoreverses = YES;
        animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        CATransform3D tranform = CATransform3DIdentity;
        tranform = CATransform3DScale(tranform, 1.6, 1.6, 1.6);
        tranform = CATransform3DTranslate(tranform, 0, 0, 10.0);
        animation.toValue = [NSValue valueWithCATransform3D:tranform];
        [cell.likeIconImageView.layer addAnimation:animation forKey:@"bulge"];
      });
      
    } else; {
      DDLogWarn(@"%@ showPhoto:%llu no indexPath for photoId found.",
                [self.class description],
                photoId);
    }
  });
}



@end
