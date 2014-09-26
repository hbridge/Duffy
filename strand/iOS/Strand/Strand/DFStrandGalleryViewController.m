//
//  DFStrandGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandGalleryViewController.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStackCell.h"
#import "DFPhoto.h"
#import "DFImageStore.h"
#import "DFSettingsViewController.h"
#import "DFFeedViewController.h"
#import "RootViewController.h"
#import "DFAnalytics.h"
#import "DFGalleryCollectionViewFlowLayout.h"
#import "NSString+DFHelpers.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFStrandGallerySectionHeaderView.h"
#import "DFStrandGalleryTitleView.h"
#import "DFInviteStrandViewController.h"
#import "DFNavigationController.h"

static const CGFloat StrandGalleryItemSize = 159.5;
static const CGFloat StrandGalleryItemSpacing = 0.5;

@interface DFStrandGalleryViewController ()

@end

@implementation DFStrandGalleryViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [self configureNavBar];
  
  self.hidesBottomBarWhenPushed = YES;
  [self configureCollectionView];
}

- (void)configureNavBar
{
  self.peopleLabel.text = [@"with " stringByAppendingString:[self.strandPosts.actorNames
                                                             componentsJoinedByString:@", "]];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithImage:[UIImage imageNamed:@"Assets/Icons/InviteBarButton"]
                                            style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(inviteButtonPressed:)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setStrandPosts:(DFPeanutFeedObject *)strandPosts
{
  _strandPosts = strandPosts;
  
  DFStrandGalleryTitleView *titleView = [[[UINib nibWithNibName:NSStringFromClass([DFStrandGalleryTitleView class])
                                       bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
  titleView.locationLabel.text = strandPosts.location;
  titleView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_taken
                                                             abbreviate:NO];
  
  self.navigationItem.titleView = titleView;
  [self.collectionView reloadData];
}

- (void)initNavigationAndTab
{
  self.navigationItem.title = self.strandPosts.title;
}

- (void)configureCollectionView
{
   self.collectionView.scrollsToTop = YES;
  
  self.collectionView.contentInset = UIEdgeInsetsMake(self.peopleBackgroundView.frame.size.height, 0, 0, 0);
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"photoCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"clusterCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFStrandGallerySectionHeaderView" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionFooter" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footerView"];
  
  
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.flowLayout.headerReferenceSize = CGSizeMake(self.view.frame.size.width, 51.0);
  self.flowLayout.footerReferenceSize = CGSizeMake(self.view.frame.size.width, 30.0);
  self.flowLayout.itemSize = CGSizeMake(StrandGalleryItemSize, StrandGalleryItemSize);
  self.flowLayout.minimumInteritemSpacing = StrandGalleryItemSpacing;
  self.flowLayout.minimumLineSpacing = StrandGalleryItemSpacing;
  
  
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
  return self.strandPosts.objects.count;
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    return [self headerForIndexPath:indexPath];
  } else if (kind == UICollectionElementKindSectionFooter) {
    view = [self.collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                   withReuseIdentifier:@"footerView"
                                                          forIndexPath:indexPath];
  }
  
  return view;
}

- (UICollectionReusableView *)headerForIndexPath:(NSIndexPath *)indexPath
{
  DFStrandGallerySectionHeaderView *headerView = [self.collectionView
                                        dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                        withReuseIdentifier:@"headerView"
                                        forIndexPath:indexPath];
  
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  
  headerView.actorLabel.text = postObject.actorNames.firstObject;
  headerView.actionLabel.text = postObject.title;
  headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:postObject.time_taken
                                                                abbreviate:YES];
  headerView.profilePhotoView.names = postObject.actorNames;
  headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:postObject.time_stamp
                                                                abbreviate:NO];
  return headerView;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  DFPeanutFeedObject *postObject = [self postObjectForSection:section];
  
  NSArray *items = postObject.enumeratorOfDescendents.allObjects;
  return items.count;
}

- (DFPeanutFeedObject *)postObjectForSection:(NSUInteger)tableSection
{
  return self.strandPosts.objects[tableSection];
}

- (DFPeanutFeedObject *)photoForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  NSArray *itemsForPost = postObject.enumeratorOfDescendents.allObjects;
  DFPeanutFeedObject *peanutPhoto = itemsForPost[indexPath.row];
  return peanutPhoto;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutFeedObject *peanutPhoto = [self photoForIndexPath:indexPath];
  
  if ([peanutPhoto.type isEqual:DFFeedObjectPhoto]) {
    cell = [self cellForPhoto:peanutPhoto indexPath:indexPath];
  } else {
    // we don't know what type this is, show an unknown cell on Dev and make a best effort on prod
    cell = [self cellForUnknownObject:peanutPhoto atIndexPath:indexPath];
  }
  
  [cell setNeedsLayout];
  return cell;
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

- (UICollectionViewCell *)cellForPhoto:(DFPeanutFeedObject *)photoObject
                             indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  
  NSArray *likeActions = [photoObject actionsOfType:DFPeanutActionFavorite forUser:0];
  cell.likeIconImageView.hidden = (likeActions.count <= 0);
  DFImageType preferredType = DFImageFull;
  
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:preferredType
   thumbnailPath:photoObject.thumb_image_path
   fullPath:photoObject.full_image_path
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
   thumbnailPath:firstObject.thumb_image_path
   fullPath:firstObject.full_image_path
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
  DFPhotoIDType photoID;
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  DFPeanutFeedObject *peanutPhoto = [self photoForIndexPath:indexPath];
  if ([peanutPhoto.type isEqualToString:DFFeedObjectPhoto]) {
    photoID = peanutPhoto.id;
  }
  
  DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] init];
  photoFeedController.strandObjects = @[postObject];
  [self.navigationController pushViewController:photoFeedController animated:YES];
  dispatch_async(dispatch_get_main_queue(), ^{
    [photoFeedController showPhoto:photoID animated:NO];
  });
}

- (void)inviteButtonPressed:(id)sender
{
  DFInviteStrandViewController *vc = [[DFInviteStrandViewController alloc] init];
  vc.sectionObject = self.strandPosts;
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:vc]
                     animated:YES
                   completion:nil];

}

@end
