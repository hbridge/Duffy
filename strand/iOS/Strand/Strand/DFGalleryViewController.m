//
//  DFGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGalleryViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFGallerySectionHeader.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "UICollectionView+DFExtras.h"
#import "DFFeedViewController.h"

@interface DFGalleryViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;

@end

@implementation DFGalleryViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureNavAndTab];
    [self observeNotifications];
    self.numPhotosPerRow = 4;
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Photos";
  self.tabBarItem.title = @"Photos";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButtonSelected"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createButtonPressed:)];
  
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.datasource = [[DFImageDataSource alloc]
                     initWithCollectionFeedObjects:[[DFPeanutFeedDataManager sharedManager]
                                                    acceptedStrandsWithPostsCollapsed:YES
                                                    feedObjectSortKey:@"time_taken"
                                                    ascending:YES]
                     collectionView:self.collectionView];
  self.datasource.imageDataSourceDelegate = self;
  [self.collectionView registerNib:[UINib nibForClass:[DFGallerySectionHeader class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"header"];
  self.flowLayout.headerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, 70);
  self.collectionView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  if (self.isMovingToParentViewController) {
    [self.collectionView scrollToBottom];
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGFloat usableWidth = self.collectionView.frame.size.width -
  ((CGFloat)(self.numPhotosPerRow - 1)  * self.flowLayout.minimumInteritemSpacing);
  CGFloat itemSize = usableWidth / (CGFloat)self.numPhotosPerRow;
  CGSize oldSize = self.flowLayout.itemSize;
  CGSize newSize =  CGSizeMake(itemSize, itemSize);
  if (!CGSizeEqualToSize(oldSize, newSize)) {
    self.flowLayout.itemSize = newSize;
    [self.collectionView reloadData];
  }
  [self.flowLayout invalidateLayout];
}

- (void)reloadData
{
  self.datasource.collectionFeedObjects = [[DFPeanutFeedDataManager sharedManager]
                                           acceptedStrandsWithPostsCollapsed:YES
                                           feedObjectSortKey:@"time_taken"
                                           ascending:YES];
  [self.collectionView reloadData];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  DFGallerySectionHeader *header = [self.collectionView
                                              dequeueReusableSupplementaryViewOfKind:kind
                                              withReuseIdentifier:@"header"
                                              forIndexPath:indexPath];
  
  
  DFPeanutFeedObject *strandObject = self.datasource.collectionFeedObjects[indexPath.section];
  header.titleLabel.text = strandObject.title;
  header.profilePhotoStackView.peanutUsers = strandObject.actors;
  header.timeLabel.text = [[NSDateFormatter HumanDateFormatter] stringFromDate:strandObject.time_taken];

  
  return header;
}

- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource
{
  [self.collectionView scrollToBottom];
}

#pragma mark - Actions

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *strandObject = self.datasource.collectionFeedObjects[indexPath.section];
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath] leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  DFFeedViewController *fvc = [[DFFeedViewController alloc] initWithFeedObject:strandObject];
  fvc.onViewScrollToPhotoId = photo.id;
  fvc.showPersonPerPhoto = YES;
  [self.navigationController pushViewController:fvc animated:YES];
}

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}

@end
