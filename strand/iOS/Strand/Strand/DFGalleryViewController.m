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
#import "DFPhotoDetailViewController.h"
#import "DFNoTableItemsView.h"
#import "DFDismissableModalViewController.h"

@interface DFGalleryViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;

@end

@implementation DFGalleryViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureNavAndTab];
    [self observeNotifications];
    self.numPhotosPerRow = 3;
  }
  return self;
}

- (instancetype)initWithFilterUser:(DFPeanutUserObject *)user
{
  self = [self init];
  if (self) {
    _userToFilterTo = user;
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
  
  NSArray *photos = [[DFPeanutFeedDataManager sharedManager]
                     photosWithUserID:self.userToFilterTo.id
                     evaluated:YES];
  self.datasource = [[DFImageDataSource alloc]
                     initWithFeedPhotos:photos
                     collectionView:self.collectionView];
  
  self.datasource.imageDataSourceDelegate = self;
  if (self.showHeaders) {
    [self.collectionView registerNib:[UINib nibForClass:[DFGallerySectionHeader class]]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                 withReuseIdentifier:@"header"];
    self.flowLayout.headerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, 70);
  }
  self.collectionView.delegate = self;
  self.datasource.showActionsBadge = YES;
  [self configureNoResultsView];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshInboxFromServer:nil];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
  [super didMoveToParentViewController:parent];
  [self.collectionView scrollToBottom];
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
    [self.flowLayout invalidateLayout];
    [self.collectionView reloadData];
  }
  [self.flowLayout invalidateLayout];
}

- (void)reloadData
{
  NSArray *photos = [[DFPeanutFeedDataManager sharedManager] photosWithUserID:self.userToFilterTo.id
                                                                  evaluated:YES];
  if (photos) {
    self.datasource.sections = [NSArray new];
    [self.collectionView reloadData];
  }
    [self configureNoResultsView];
}

- (void)configureNoResultsView
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.datasource numberOfSectionsInCollectionView:self.collectionView] == 0) {
      if (!self.noResultsView) self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
      [self.noResultsView setSuperView:self.collectionView];
      if ([[DFPeanutFeedDataManager sharedManager] hasInboxData]) {
        self.noResultsView.titleLabel.text = @"No Photos";
        [self.noResultsView.activityIndicator stopAnimating];
      } else {
        self.noResultsView.titleLabel.text = @"Loading...";
        [self.noResultsView.activityIndicator startAnimating];
      }
    } else {
      if (self.noResultsView) [self.noResultsView removeFromSuperview];
      self.noResultsView = nil;
    }
  });
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  DFGallerySectionHeader *header = [self.collectionView
                                              dequeueReusableSupplementaryViewOfKind:kind
                                              withReuseIdentifier:@"header"
                                              forIndexPath:indexPath];
  
//  DFPeanutFeedObject *strandObject = self.datasource.collectionFeedObjects[indexPath.section];
//  header.titleLabel.text = strandObject.title;
//  header.profilePhotoStackView.peanutUsers = strandObject.actors;
//  header.timeLabel.text = [[NSDateFormatter HumanDateFormatter] stringFromDate:strandObject.time_taken];
  
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
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath]
                                leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  DFPhotoDetailViewController *evc = [[DFPhotoDetailViewController alloc]
                                      initWithPhotoObject:photo];
  [DFDismissableModalViewController presentWithRootController:evc inParent:self];
}

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}

@end
