//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosViewController.h"
#import "DFCameraRollSyncManager.h"
#import "DFPeanutFeedAdapter.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "DFGallerySectionHeader.h"
#import "DFCardTableViewCell.h"
#import "DFPeanutFeedObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFSelectPhotosController.h"
#import "DFPeanutFeedDataManager.h"
#import "NSString+DFHelpers.h"
#import "DFStrandConstants.h"
#import "DFPeanutUserObject.h"
#import "DFInboxTableViewCell.h"
#import "UIDevice+DFHelpers.h"
#import "NSArray+DFHelpers.h"
#import "UINib+DFHelpers.h"
#import "DFAnalytics.h"
#import "DFPhotoViewCell.h"
#import "DFPhotoPickerHeaderReusableView.h"
#import "DFSelectableMultiPhotoViewController.h"


const CGFloat CreateCellWithTitleHeight = 192;
const CGFloat CreateCellTitleHeight = 20;
const CGFloat CreateCellTitleSpacing = 8;


@interface DFSelectPhotosViewController ()

@property (nonatomic, retain) DFPeanutObjectsResponse *allObjectsResponse;
@property (nonatomic, retain) NSMutableArray *suggestionObjects;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;
@property (nonatomic, retain) NSTimer *refreshTimer;
@property (atomic, retain) NSTimer *showReloadButtonTimer;

@property (nonatomic, retain) NSMutableDictionary *sectionsToHeaderViews;
@property (nonatomic, retain) NSMutableDictionary *stylesToHeaderHeights;
@property (nonatomic) BOOL didAppear;


@end

@implementation DFSelectPhotosViewController

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
{
  self = [self init];
  if (self) {
    _collectionFeedObjects = collectionFeedObjects;
  }
  return self;
}

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                        highlightedFeedObject:(DFPeanutFeedObject *)highlightedObject
{
  self = [self initWithCollectionFeedObjects:collectionFeedObjects];
  if (self) {
    _highlightedFeedObject = highlightedObject;
  }
  return self;
}

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _actionButtonVerb = @"Select";
    _sectionsToHeaderViews = [NSMutableDictionary new];
    _stylesToHeaderHeights = [NSMutableDictionary new];
    [self configureNavAndTab];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/CreateStrandBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  }
  return self;
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Swap Photos";
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/CreateBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/CreateBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

}

- (void)setCollectionFeedObjects:(NSArray *)collectionFeedObjects
{
  _collectionFeedObjects = collectionFeedObjects;
  [self.selectPhotosController setCollectionFeedObjects:collectionFeedObjects];
}

- (NSArray *)selectedObjects{
  return self.selectPhotosController.selectedFeedObjects;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureCollectionView];
  [self.collectionView reloadData];
  [self configureDoneButtonText];
}

- (void)configureCollectionView
{
  self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, self.doneWrapper.frame.size.height * 2.0, 0);
  NSArray *styles = @[@(DFPhotoPickerHeaderStyleTimeOnly),
                      @(DFPhotoPickerHeaderStyleLocation),
                      @(DFPhotoPickerHeaderStyleLocation | DFPhotoPickerHeaderStyleBadge),
                      @(DFPhotoPickerHeaderStyleBadge),
                      ];
  for (NSNumber *style in styles) {
    [self.collectionView registerNib:[UINib nibForClass:[DFPhotoPickerHeaderReusableView class]]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                 withReuseIdentifier:style.stringValue];
  }
  
  self.selectPhotosController = [[DFSelectPhotosController alloc]
                                 initWithCollectionFeedObjects:self.collectionFeedObjects
                                 collectionView:self.collectionView];
  self.selectPhotosController.supplementaryViewDelegate = self;
  self.selectPhotosController.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  UINavigationBar *navigationBar = self.navigationController.navigationBar;
  
  [navigationBar setBackgroundImage:[UIImage new]
                     forBarPosition:UIBarPositionAny
                         barMetrics:UIBarMetricsDefault];
  
  [navigationBar setShadowImage:[UIImage new]];
  
  [self.collectionView reloadData];
  if (self.navigationController.isBeingPresented) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancelPressed:)];
  }
  
  if (self.isMovingToParentViewController) {
    if (self.highlightedFeedObject) {
      [self scrollToHighlightedFeedObject];
    } else {
      [self scrollToLast];
    }
  }
}

- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource
{
  if (self.highlightedFeedObject) {
    [self scrollToHighlightedFeedObject];
  } else {
    [self scrollToLast];
  }
}

- (void)scrollToLast
{
  DFSelectPhotosViewController __weak *weakSelf = self;// avoid capture
  
  dispatch_async(dispatch_get_main_queue(), ^{
    NSInteger lastSection = [weakSelf.collectionView numberOfSections] - 1;
    NSInteger lastItem =  [weakSelf.collectionView numberOfItemsInSection:lastSection] - 1;
    NSIndexPath *lastIP = [NSIndexPath indexPathForItem:lastItem inSection:lastSection];
    if (![weakSelf isIndexPathValid:lastIP]) return;

    [weakSelf.collectionView scrollToItemAtIndexPath:lastIP
                           atScrollPosition:UICollectionViewScrollPositionTop
                                   animated:NO];
  });
  
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
  self.didAppear = YES;
}

- (void)scrollToHighlightedFeedObject
{
  DFSelectPhotosViewController __weak *weakSelf = self;// avoid capture

  dispatch_async(dispatch_get_main_queue(), ^{
    NSInteger sectionForObject = [weakSelf.selectPhotosController.collectionFeedObjects
                                  indexOfObject:weakSelf.highlightedFeedObject];
    NSIndexPath *indexPathForObject = [NSIndexPath indexPathForItem:0 inSection:sectionForObject];
    
    if ([weakSelf isIndexPathValid:indexPathForObject]) {
      UICollectionView *collectionView = weakSelf.collectionView;
      UICollectionViewLayoutAttributes *headerLayoutAttributes =
      [collectionView layoutAttributesForSupplementaryElementOfKind:UICollectionElementKindSectionHeader
                                                        atIndexPath:indexPathForObject];
      CGRect rectToScroll = headerLayoutAttributes.frame;
      if (!self.didAppear) {
        // for some reason, the origin calculation for layout is off before viewDidAppear
        rectToScroll.origin.y -= collectionView.contentInset.bottom;
      }
      rectToScroll.size.height = collectionView.frame.size.height;
      [collectionView scrollRectToVisible:rectToScroll animated:NO];
      
      [weakSelf.selectPhotosController toggleSectionSelection:sectionForObject];
    }
  });
}

- (BOOL)isIndexPathValid:(NSIndexPath *)indexPath
{
  if (indexPath.section == NSNotFound) return NO;
  if (indexPath.section < 0 || indexPath.section >= self.collectionView.numberOfSections) return NO;
  if (indexPath.row < 0 || indexPath.row >= [self.collectionView numberOfItemsInSection:indexPath.section]) return NO;
  return YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self.refreshTimer invalidate];
  self.refreshTimer = nil;
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  self.flowLayout.headerReferenceSize = CGSizeMake(self.view.frame.size.width, 51);
  CGFloat itemSize = (self.collectionView.frame.size.width - StrandGalleryItemSpacing*3.0)/4.0;
  self.flowLayout.itemSize = CGSizeMake(itemSize, itemSize);
  self.flowLayout.minimumInteritemSpacing = StrandGalleryItemSpacing;
  self.flowLayout.minimumLineSpacing = StrandGalleryItemSpacing * 1.5; // for some reason the
                                                                       // line spacing sometimes
                                                                       // disapppears at 0.5
  
  self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, self.doneWrapper.frame.size.height * 2.0, 0);
}

#pragma mark - UICollectionView Data/Delegate


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    return [self headerForIndexPath:indexPath];
  }
  
  return view;
}



- (UICollectionReusableView *)headerForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *suggestion = self.selectPhotosController.collectionFeedObjects[indexPath.section];
  DFPhotoPickerHeaderStyle style = [self styleForSuggestion:suggestion];

  DFPhotoPickerHeaderReusableView *headerView = [self.collectionView
                  dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                 withReuseIdentifier:[@(style) stringValue]
                                                 forIndexPath:indexPath];
  [headerView configureWithStyle:style];
  
  headerView.locationLabel.text = suggestion.location;
  headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:suggestion.time_taken
                                                                abbreviate:NO];
  headerView.badgeIconView.image = [UIImage imageNamed:@"Assets/Icons/MatchedIcon"];
  
  if (suggestion.actors.count == 1) {
    headerView.badgeIconText.text = [NSString stringWithFormat:@"%@ has photos to swap", suggestion.actorsString];
  } else {
    headerView.badgeIconText.text = [NSString stringWithFormat:@"%@ have photos to swap", suggestion.actorsString];
  }
  
  [self configureHeaderButtonForHeader:headerView section:indexPath.section];
  DFSelectPhotosViewController __weak *weakSelf = self;
  DFPhotoPickerHeaderReusableView __weak *weakHeader = headerView; // cast to prevent retain cycle
  headerView.shareCallback = ^{
    [weakSelf shareButtonPressedForHeaderView:weakHeader
                                  section:indexPath.section];
  };
  headerView.removeSuggestionCallback = ^{
    [weakSelf removeSuggestionPressedForHeaderView:weakHeader
                                           section:indexPath.section];
  };
  
  self.sectionsToHeaderViews[@(indexPath.section)] = headerView;
  
  return headerView;
}

- (DFPhotoPickerHeaderStyle)styleForSuggestion:(DFPeanutFeedObject *)suggestion
{
  DFPhotoPickerHeaderStyle style = DFPhotoPickerHeaderStyleTimeOnly;
  if (suggestion.suggestible.boolValue) {
    if (suggestion.location) style |= DFPhotoPickerHeaderStyleLocation;
    if (suggestion.actors.count > 0) style |= DFPhotoPickerHeaderStyleBadge;
  }
  
  return style;
}

- (void)configureHeaderButtonForHeader:(DFPhotoPickerHeaderReusableView *)headerView
                               section:(NSUInteger)section
{
  NSString *newTitle;
  if ([[self.selectPhotosController selectedItemsFromSection:section] count] > 0) {
    newTitle = @"Deselect";
  } else {
    newTitle = @"Select";
  }
  if (![[headerView.shareButton titleForState:UIControlStateNormal] isEqual:newTitle])
    [headerView.shareButton setTitle:newTitle forState:UIControlStateNormal];
}


- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section
{
  DFPeanutFeedObject *suggestion = self.selectPhotosController.collectionFeedObjects[section];
  DFPhotoPickerHeaderStyle style = [self styleForSuggestion:suggestion];
  
  NSNumber *result = self.stylesToHeaderHeights[@(style)];
  if (!result) {
    result = @([DFPhotoPickerHeaderReusableView heightForStyle:style]);
    self.stylesToHeaderHeights[@(style)] = result;
  }
  
  return CGSizeMake(self.view.frame.size.width, result.floatValue);
}



#pragma mark - Actions

- (void)shareButtonPressedForHeaderView:(DFPhotoPickerHeaderReusableView *)headerView
                              section:(NSUInteger)section
{
  [self.selectPhotosController toggleSectionSelection:section];
  [self configureHeaderButtonForHeader:headerView section:section];
}

- (void)removeSuggestionPressedForHeaderView:(DFPhotoPickerHeaderReusableView *)headerView
                                           section:(NSUInteger)section
{
  DFPeanutFeedObject *suggestion = self.selectPhotosController.collectionFeedObjects[section];
  [[DFPeanutFeedDataManager sharedManager] markSuggestion:suggestion visible:NO];
  suggestion.suggestible = @NO;
  [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:section]];
}

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
    selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  NSSet *visibleSections = [NSSet setWithArray:[[self.collectionView indexPathsForVisibleItems]
                                                valueForKey:@"section"]];
  for (NSNumber *section in visibleSections) {
    DFPhotoPickerHeaderReusableView *headerView = self.sectionsToHeaderViews[section];
    [self configureHeaderButtonForHeader:headerView section:(NSUInteger)section.longLongValue];
  }
  [self configureDoneButtonText];
}

- (void)configureDoneButtonText
{
  int selectedCount = (int)self.selectPhotosController.selectedPhotoIDs.count;
  NSString *buttonText;
  if (selectedCount == 0) {
    if (self.allowsNilSelection) {
      self.doneButton.enabled = YES;
      buttonText = @"Skip";
    } else {
      self.doneButton.enabled = NO;
      buttonText = @"None Selected";
    }
  } else {
    if (!self.allowsNilSelection) self.doneButton.enabled = YES;
    buttonText = [NSString stringWithFormat:@"%@ %d Photos", self.actionButtonVerb, selectedCount];
  }
  
  [self.doneButton setTitle:buttonText forState:UIControlStateNormal];
}


- (void)cancelPressed:(id)sender
{
  [self.delegate selectPhotosViewController:self
              didFinishSelectingFeedObjects:nil];
}

- (IBAction)doneButtonPressed:(UIButton *)sender {
  DFSelectPhotosController *selectPhotosController = self.selectPhotosController;
  [self.delegate selectPhotosViewController:self
              didFinishSelectingFeedObjects:selectPhotosController.selectedFeedObjects];
}

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
         feedObjectLongpressed:(DFPeanutFeedObject *)feedObject inSection:(NSUInteger)section
{
  DFPeanutFeedObject *photoObject = [[feedObject leafNodesFromObjectOfType:DFFeedObjectPhoto]
                                     firstObject];
  
  DFSelectableMultiPhotoViewController *mpvc = [[DFSelectableMultiPhotoViewController alloc]
                                                initWithActivePhoto:photoObject
                                                inSection:section
                                                ofSelectPhotosController:self.selectPhotosController];
  [self presentViewController:mpvc animated:YES completion:nil];
}


@end
