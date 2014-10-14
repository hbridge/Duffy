//
//  DFAddPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectSuggestionsViewController.h"
#import "DFSelectPhotosController.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "NSString+DFHelpers.h"
#import "SVProgressHUD.h"
#import "DFStrandConstants.h"
#import "DFPhotoStore.h"
#import "DFPushNotificationsManager.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSArray+DFHelpers.h"

@interface DFSelectSuggestionsViewController ()

@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;

@end

@implementation DFSelectSuggestionsViewController


NSUInteger const DefaultNumSuggestedPhotosPerRow = 4;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions
{
  self = [super init];
  if (self) {
    _suggestionsObject = suggestions;
    _numPhotosPerRow = DefaultNumSuggestedPhotosPerRow;
  }
  
  return self;
}

- (IBAction)selectAllButtonPressed:(UIButton *)sender {
  // if everything's selected, deselect all
  NSString *newTitle;
  BOOL showTickMark;
  
  if (self.selectPhotosController.selectedFeedObjects.count == self.suggestionsObject.objects.count) {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Select All";
    showTickMark = NO;
  } else {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Deselect All";
    showTickMark = YES;
    [self.selectPhotosController.selectedFeedObjects addObjectsFromArray:self.suggestionsObject.objects];
  }
  
  for (DFSelectablePhotoViewCell *cell in self.collectionView.visibleCells) {
    cell.showTickMark = showTickMark;
    [cell setNeedsLayout];
  }
  [self.selectAllButton setTitle:newTitle forState:UIControlStateNormal];
  [self configureNavTitle];
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureHeader];
  [self configureCollectionView];
  [self configureNavTitle];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGFloat usableWidth = self.collectionView.frame.size.width -
  ((CGFloat)(self.numPhotosPerRow - 1)  * self.flowLayout.minimumInteritemSpacing);
  CGFloat itemSize = usableWidth / (CGFloat)self.numPhotosPerRow;
  self.flowLayout.itemSize = CGSizeMake(itemSize, itemSize);
}

- (void)configureHeader
{
  self.locationLabel.text = self.suggestionsObject.location;
  self.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:self.suggestionsObject.time_taken
                                                          abbreviate:NO];
}

- (void)configureCollectionView
{
  self.selectPhotosController = [[DFSelectPhotosController alloc]
                                 initWithFeedPhotos:self.suggestionsObject.objects
                                 collectionView:self.collectionView
                                 sourceMode:DFImageDataSourceModeLocal
                                 imageType:DFImageThumbnail];
  self.selectPhotosController.delegate = self;
  self.collectionView.alwaysBounceVertical = YES;
}

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
    selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  [self configureNavTitle];
}

- (void)configureNavTitle
{
  NSUInteger selectedPhotosCount = self.selectPhotosController.selectedPhotoIDs.count;
  
  // set the title based on photos selected
  if (selectedPhotosCount == 0) {
    self.navigationItem.title = @"No Photos Selected";
    self.navigationItem.rightBarButtonItem.enabled = NO;
  } else {
    NSString *title = [NSString stringWithFormat:@"%d Photos Selected",
                       (int)selectedPhotosCount];
    self.navigationItem.title = title;
    self.navigationItem.rightBarButtonItem.enabled = YES;
  }
}


@end
