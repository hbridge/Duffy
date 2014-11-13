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
#import "DFImageManager.h"
#import "DFSettingsViewController.h"
#import "DFFeedViewController.h"
#import "DFAnalytics.h"
#import "DFGalleryCollectionViewFlowLayout.h"
#import "NSString+DFHelpers.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFStrandGallerySectionHeaderView.h"
#import "DFStrandGalleryTitleView.h"
#import "DFInviteStrandViewController.h"
#import "DFNavigationController.h"

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
  self.peopleLabel.text = self.strandPosts.actorsString;
  NSString *invitedPeopleText = [self.strandPosts invitedActorsStringCondensed:NO];
  if ([invitedPeopleText isNotEmpty]) {
    self.invitedPeopleLabel.text = invitedPeopleText;
  } else {
    [self.invitedPeopleIcon removeFromSuperview];
    [self.invitedPeopleLabel removeFromSuperview];
  }
  
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
  self.collectionView.alwaysBounceVertical = YES;
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"photoCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"clusterCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFStrandGallerySectionHeaderView" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  
  self.collectionView.backgroundColor = [UIColor whiteColor];
 }

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  self.flowLayout.headerReferenceSize = CGSizeMake(self.view.frame.size.width, StrandGalleryHeaderHeight);
  CGFloat itemSize = (self.collectionView.frame.size.width - StrandGalleryItemSpacing)/2.0;
  self.flowLayout.itemSize = CGSizeMake(itemSize, itemSize);
  self.flowLayout.minimumInteritemSpacing = StrandGalleryItemSpacing;
  self.flowLayout.minimumLineSpacing = StrandGalleryItemSpacing * 1.5; // for some reason the
                                                                       // line spacing sometimes
                                                                       // disapppears at 0.5

}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
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
  headerView.profilePhotoView.peanutUsers = postObject.actors;
  headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:postObject.time_stamp
                                                                abbreviate:NO];
  return headerView;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  DFPeanutFeedObject *postObject = [self postObjectForSection:section];
  
  NSArray *items = postObject.objects;
  return items.count;
}

- (DFPeanutFeedObject *)postObjectForSection:(NSUInteger)tableSection
{
  return self.strandPosts.objects[tableSection];
}

- (DFPeanutFeedObject *)photoForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  NSArray *itemsForPost = postObject.objects;
  DFPeanutFeedObject *peanutPhoto = itemsForPost[indexPath.row];
  return peanutPhoto;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutFeedObject *feedObject = [self photoForIndexPath:indexPath];
  
  if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
    cell = [self cellForPhoto:feedObject indexPath:indexPath];
  }else if ([feedObject.type isEqual:DFFeedObjectCluster]){
    cell = [self cellForCluster:feedObject indexPath:indexPath];
  } else {
    // we don't know what type this is, show an unknown cell on Dev and make a best effort on prod
    cell = [self cellForUnknownObject:feedObject atIndexPath:indexPath];
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
  cell.imageView.backgroundColor = [UIColor lightGrayColor];
  [cell.loadingActivityIndicator startAnimating];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  
  NSArray *likeActions = [photoObject actionsOfType:DFPeanutActionFavorite forUser:0];
  cell.likeIconImageView.hidden = (likeActions.count <= 0);
  DFImageType preferredType = DFImageFull;
  
  [[DFImageManager sharedManager]
   imageForID:photoObject.id
   preferredType:preferredType
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       if
         (image) cell.imageView.image = image;
       else
         cell.imageView.image = [UIImage imageNamed:@"Assets/Icons/MissingImage320"];
       [cell.loadingActivityIndicator stopAnimating];
       [cell setNeedsLayout];
     });
   }];
  
  return cell;
}

- (UICollectionViewCell *)cellForCluster:(DFPeanutFeedObject *)clusterObject
                               indexPath:(NSIndexPath *)indexPath
{
  DFPhotoStackCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"clusterCell"
                                                                         forIndexPath:indexPath];
  cell.imageView.backgroundColor = [UIColor lightGrayColor];
  cell.imageView.image = nil;
  [cell.loadingActivityIndicator startAnimating];
  for (DFPeanutFeedObject *object in clusterObject.objects) {
    if ([[object actionsOfType:DFPeanutActionFavorite forUser:0] count] > 0) {
      break;
    }
  }
  
  DFPeanutFeedObject *firstObject = (DFPeanutFeedObject *)clusterObject.objects.firstObject;
  
  [[DFImageManager sharedManager]
   imageForID:firstObject.id
   preferredType:DFImageFull
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       [cell.loadingActivityIndicator stopAnimating];
       cell.count = clusterObject.objects.count;
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
  DFPeanutFeedObject *feedObject = [self photoForIndexPath:indexPath];
  if ([feedObject.type isEqualToString:DFFeedObjectPhoto]) {
    photoID = feedObject.id;
  } else if ([feedObject.type isEqualToString:DFFeedObjectCluster]) {
    photoID = ((DFPeanutFeedObject *)feedObject.objects.firstObject).id;
  }
  
  DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] initWithFeedObject:self.strandPosts];
  [self.navigationController pushViewController:photoFeedController animated:YES];
  photoFeedController.onViewScrollToPhotoId = photoID;
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
