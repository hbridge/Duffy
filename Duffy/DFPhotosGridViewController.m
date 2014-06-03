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

@interface DFPhotosGridViewController ()

@end

@implementation DFPhotosGridViewController

@synthesize photoSpacing;
@synthesize photoSquareSize;
@synthesize photosBySection = _photosBySection;
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
    
    photoSquareSize = DEFAULT_PHOTO_SQUARE_SIZE;
    photoSpacing = DEFAULT_PHOTO_SPACING;
    
    _photosBySection = [[NSDictionary alloc] init];
    _sectionNames = [[NSArray alloc] init];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // configure our flow layout
  self.flowLayout = [[UICollectionViewFlowLayout alloc] init];
  self.flowLayout.itemSize =CGSizeMake(self.photoSquareSize, self.photoSquareSize);
  self.flowLayout.minimumInteritemSpacing = self.photoSpacing;
  self.flowLayout.minimumLineSpacing = self.photoSpacing;
  [self.collectionView setCollectionViewLayout:self.flowLayout];
  self.collectionView.contentInset = UIEdgeInsetsMake(self.photoSpacing, 0, 0, 0);
  self.flowLayout.headerReferenceSize = CGSizeMake(320, 33);
  
  
  // register cell type
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil] forCellWithReuseIdentifier:@"DFPhotoViewCell"];
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

- (void)setSectionNames:(NSArray *)sectionNames photosBySection:(NSDictionary *)photosBySection
{
  _sectionNames = sectionNames;
  _photosBySection = photosBySection;
  
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
  NSArray *photos = [self resultsForSectionIndex:section];
  return photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *photosForSection = [self resultsForSectionIndex:indexPath.section];
  DFPhoto *photo = photosForSection[indexPath.row];
  
  DFPhotoViewCell *cell = (DFPhotoViewCell *)[self.collectionView
                                              dequeueReusableCellWithReuseIdentifier:@"DFPhotoViewCell" forIndexPath:indexPath];
  [cell.imageView setImage:[photo thumbnail]];
  
  return cell;
}


- (NSArray *)resultsForSectionIndex:(NSInteger)index
{
  if (index > self.sectionNames.count) return nil;
  NSString *sectionName = self.sectionNames[index];
  NSArray *photos = self.photosBySection[sectionName];
  return photos;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *reusableview = nil;
  
  if (kind == UICollectionElementKindSectionHeader) {
    DFPhotoSectionHeader *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
    NSString *title = self.sectionNames[indexPath.section];
    headerView.titleLabel.text = title;
    
    reusableview = headerView;
  }
  
  if (kind == UICollectionElementKindSectionFooter) {
    UICollectionReusableView *footerview = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"FooterView" forIndexPath:indexPath];
    
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
  
  NSArray *photosForSection = [self resultsForSectionIndex:indexPath.section];
  DFPhoto *photo = photosForSection[indexPath.row];
  [self pushPhotoViewForPhoto:photo atIndexPath:indexPath];
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
  
  NSArray *photosForSection = [self resultsForSectionIndex:indexPath.section];
  DFPhoto *photo = photosForSection[indexPath.row - 1];
  
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  pvc.indexPathInParent = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
  return pvc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  NSIndexPath *indexPath = ((DFPhotoViewController*)viewController).indexPathInParent;
  
  NSArray *photosForSection = [self resultsForSectionIndex:indexPath.section];
  if (indexPath.row == photosForSection.count -1) return nil;
  
  DFPhoto *photo = [photosForSection objectAtIndex:indexPath.row + 1];
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  pvc.indexPathInParent = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
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
