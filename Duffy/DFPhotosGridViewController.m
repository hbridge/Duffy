//
//  DFTimelineViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotosGridViewController.h"
#import "DFPhoto.h"
#import "DFPhotoViewCell.h"
#import "DFPhotoViewController.h"
#import "DFPhotoNavigationControllerViewController.h"
#import "DFMultiPhotoViewController.h"
#import "DFPhotoSectionHeader.h"
#import "DFPhotoStackCell.h"
#import "DFPhotoCollection.h"

@interface DFPhotosGridViewController ()

@end

@implementation DFPhotosGridViewController

@synthesize itemSpacing;
@synthesize itemSquareSize;
@synthesize itemsBySection = _itemsBySection;
@synthesize sectionNames = _sectionNames;

static const CGFloat DEFAULT_PHOTO_SQUARE_SIZE = 77;
static const CGFloat DEFAULT_PHOTO_SPACING = 4;

- (id)init
{
  self = [super initWithNibName:@"DFPhotosGridViewController" bundle:[NSBundle mainBundle]];
  if (self) {
    self.tabBarItem.title = @"Photos";
    self.tabBarItem.image = [UIImage imageNamed:@"Icons/Timeline"];
    
    UINavigationItem *n = [self navigationItem];
    [n setTitle:@"Photos"];
    
    itemSquareSize = DEFAULT_PHOTO_SQUARE_SIZE;
    itemSpacing = DEFAULT_PHOTO_SPACING;
    
    _itemsBySection = [[NSDictionary alloc] init];
    _sectionNames = [[NSArray alloc] init];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // configure our flow layout
  self.flowLayout = [[UICollectionViewFlowLayout alloc] init];
  self.flowLayout.itemSize =CGSizeMake(self.itemSquareSize, self.itemSquareSize);
  self.flowLayout.minimumInteritemSpacing = self.itemSpacing;
  self.flowLayout.minimumLineSpacing = self.itemSpacing;
  [self.collectionView setCollectionViewLayout:self.flowLayout];
  self.collectionView.contentInset = UIEdgeInsetsMake(self.itemSpacing, 0, 0, 0);
  self.flowLayout.headerReferenceSize = CGSizeMake(320, 33);
  
  
  // register cell type
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"DFPhotoViewCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"DFPhotoStackCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoSectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"HeaderView"];
  
  // set background
  self.collectionView.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setSectionNames:(NSArray *)sectionNames itemsBySection:(NSDictionary *)photosBySection
{
  _sectionNames = sectionNames;
  _itemsBySection = photosBySection;
  
  [self.collectionView reloadData];
}

- (void)scrollToBottom
{
  NSInteger section = 0;
  NSInteger item = [self collectionView:self.collectionView numberOfItemsInSection:section] - 1;
  NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:item inSection:section];
  if (lastIndexPath.section >= 0 && lastIndexPath.row >= 0) {
    [self.collectionView scrollToItemAtIndexPath:lastIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
  }
}


#pragma mark - UICollectionView datasource/delegate methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.sectionNames.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  NSArray *items = [self resultsForSectionIndex:section];
  return items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *result;
  
  NSArray *itemsForSection = [self resultsForSectionIndex:indexPath.section];
  id item = itemsForSection[indexPath.row];
  if ([item isKindOfClass:[DFPhoto class]]) {
    DFPhoto *photo = (DFPhoto *)item;
  
    DFPhotoViewCell *cell = (DFPhotoViewCell *)[self.collectionView
                                                dequeueReusableCellWithReuseIdentifier:@"DFPhotoViewCell"
                                                forIndexPath:indexPath];
    cell.imageView.image = photo.thumbnail;
    result = cell;
  } else if ([item isKindOfClass:[DFPhotoCollection class]]){
    DFPhotoCollection *photoCollection = (DFPhotoCollection *)item;
    DFPhotoStackCell *stackCell =
    (DFPhotoStackCell *)[self.collectionView
                         dequeueReusableCellWithReuseIdentifier:@"DFPhotoStackCell"
                         forIndexPath:indexPath];
    
    stackCell.photoImageView.image = photoCollection.thumbnail;
    stackCell.countLabel.text = [NSString stringWithFormat:@"%d",
                                (int)photoCollection.photoSet.count];
    result = stackCell;
  }
  
  return result;
}


- (NSArray *)resultsForSectionIndex:(NSInteger)index
{
  if (index > self.sectionNames.count) return nil;
  NSString *sectionName = self.sectionNames[index];
  NSArray *items = self.itemsBySection[sectionName];
  return items;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *reusableview = nil;
  
  if (kind == UICollectionElementKindSectionHeader) {
    DFPhotoSectionHeader *headerView =
    [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                       withReuseIdentifier:@"HeaderView"
                                              forIndexPath:indexPath];
    NSString *title = self.sectionNames[indexPath.section];
    headerView.titleLabel.text = title;
    
    reusableview = headerView;
  }
  
  if (kind == UICollectionElementKindSectionFooter) {
    UICollectionReusableView *footerview =
    [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                       withReuseIdentifier:@"FooterView"
                                              forIndexPath:indexPath];
    
    reusableview = footerview;
  }
  
  return reusableview;
}


#pragma mark - Notification responders

- (void)assetsEnumerated
{
  [self.collectionView reloadData];
}


#pragma mark - Action Handlers

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  
  NSArray *itemsForSection = [self resultsForSectionIndex:indexPath.section];
  id item = itemsForSection[indexPath.row];
  if ([item isKindOfClass:[DFPhoto class]]) {
    DFPhoto *photo = (DFPhoto *)item;
    [self pushPhotoViewForPhoto:photo atIndexPath:indexPath];
  } else if ([item isKindOfClass:[DFPhotoCollection class]]){
    // get the photos to replace the collection with
    DFPhotoCollection *stackCollection = item;
    NSArray *photos = [stackCollection photosByDateAscending:YES];
    
    NSMutableArray *newItemsForSection = itemsForSection.mutableCopy;
    [newItemsForSection replaceObjectsInRange:(NSRange){indexPath.row, 1}
                         withObjectsFromArray:photos];
    NSMutableDictionary *newSections = self.itemsBySection.mutableCopy;
    newSections[self.sectionNames[indexPath.section]] = newItemsForSection;
    _itemsBySection = newSections;
    [UIView animateWithDuration:0.3 animations:^{
      [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
    }];
    
  }
}

- (void)pushPhotoViewForPhoto:(DFPhoto *)photo
                  atIndexPath:(NSIndexPath *)indexPath
{
  
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  pvc.indexPathInParent = indexPath;
  
  
  DFMultiPhotoViewController *multiPhotoController = [[DFMultiPhotoViewController alloc] init];
  multiPhotoController.dataSource = self;
  [multiPhotoController setViewControllers:[NSArray arrayWithObject:pvc]
                                 direction:UIPageViewControllerNavigationDirectionForward
                                  animated:NO
                                completion:^(BOOL finished) {
                                }];
  
  DFPhotoNavigationControllerViewController *photoNavController = (DFPhotoNavigationControllerViewController *)self.navigationController;
  [photoNavController pushMultiPhotoViewController:multiPhotoController
                      withFrontPhotoViewController:pvc
                          fromPhotosGridController:self
                                   itemAtIndexPath:indexPath];
}



#pragma mark - DFMultiPhotoPageView datasource

- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSIndexPath *indexPath = ((DFPhotoViewController*)viewController).indexPathInParent;
  if (indexPath.row == 0) return nil;
  
  NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
  return [self photoViewControllerForIndexPath:newIndexPath];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  NSIndexPath *indexPath = ((DFPhotoViewController*)viewController).indexPathInParent;
  NSArray *photosForSection = [self resultsForSectionIndex:indexPath.section];
  if (indexPath.row >= photosForSection.count -1) return nil;
  
  NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
  return [self photoViewControllerForIndexPath:newIndexPath];
}

- (UIViewController *)photoViewControllerForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *itemsForSection = [self resultsForSectionIndex:indexPath.section];
  id item = itemsForSection[indexPath.row];
  DFPhoto *photo;
  if ([item isKindOfClass:[DFPhoto class]]) {
    photo = (DFPhoto *)item;
  } else if ([item isKindOfClass:[DFPhotoCollection class]]) {
    photo = (DFPhoto *)[[item photosByDateAscending:YES] firstObject];
  }
  
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  pvc.indexPathInParent = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
  return pvc;
}

- (CGRect)frameForCellAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
  if (layoutAttributes) {
    CGRect frame = layoutAttributes.frame;
    return CGRectMake(frame.origin.x,
                      frame.origin.y + self.topLayoutGuide.length - self.collectionView.contentOffset.y,
                      frame.size.width,
                      frame.size.height);
  }
  
  return CGRectZero;
}

@end
