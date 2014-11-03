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
#import "DFSelectableMultiPhotoViewController.h"

@interface DFSelectSuggestionsViewController ()

@property (nonatomic, retain) NSArray *items;

@end

@implementation DFSelectSuggestionsViewController


NSUInteger const DefaultNumSuggestedPhotosPerRow = 4;

- (instancetype)initWithSuggestions:(NSArray *)suggestedSections
{
  self = [super initWithNibName:NSStringFromClass([DFSelectSuggestionsViewController class]) bundle:nil];
  if (self) {
    _numPhotosPerRow = DefaultNumSuggestedPhotosPerRow;
    self.suggestedSections = suggestedSections;
  }
  
  return self;
}

- (void)setSuggestedSections:(NSArray *)suggestedSections
{
  // in most cases, there should only be one suggested section, but if there are multiple
  // we pull all the photos out of each section
  _suggestedSections = suggestedSections;
  NSMutableArray *items = [NSMutableArray new];
  for (DFPeanutFeedObject *section in suggestedSections) {
    [items addObjectsFromArray:section.objects];
  }
  _items = items;
  [self configureDoneButtonText];
}

- (IBAction)selectAllButtonPressed:(UIButton *)sender {
  // if everything's selected, deselect all
  NSString *newTitle;
  BOOL showTickMark;
  
  if (self.selectPhotosController.selectedFeedObjects.count == self.items.count) {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Select All";
    showTickMark = NO;
  } else {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Deselect All";
    showTickMark = YES;
    [self.selectPhotosController.selectedFeedObjects addObjectsFromArray:self.items];
  }
  
  for (DFSelectablePhotoViewCell *cell in self.collectionView.visibleCells) {
    cell.showTickMark = showTickMark;
    [cell setNeedsLayout];
  }
  [self.selectAllButton setTitle:newTitle forState:UIControlStateNormal];
  [self configureNavTitle];
  [self configureDoneButtonText];
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
  [self configureDoneButtonText];
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
  // in most cases, there should only be one suggested section
  // however, if there are multiple suggested sections, we use all the photos (see setSuggestedSections)
  // though we use the first object to configure the header
  DFPeanutFeedObject *firstSection = self.suggestedSections.firstObject;
  self.locationLabel.text = firstSection.location;
  self.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:firstSection.time_taken
                                                          abbreviate:NO];
}

- (void)configureCollectionView
{
  self.selectPhotosController = [[DFSelectPhotosController alloc]
                                 initWithFeedPhotos:self.items
                                 collectionView:self.collectionView];
  self.selectPhotosController.delegate = self;
  self.collectionView.alwaysBounceVertical = YES;
}

- (void)configureNavTitle
{
  self.navigationItem.title = @"Select Photos";
}

- (void)configureDoneButtonText
{
  int selectedCount = (int)self.selectPhotosController.selectedPhotoIDs.count;
  NSString *buttonText;
  if (selectedCount == 0) {
    if (self.allowsNilSelection) {
      self.swapButton.enabled = YES;
      buttonText = @"Skip";
    } else {
      self.swapButton.enabled = NO;
      buttonText = @"None Selected";
    }
  } else {
    if (!self.allowsNilSelection) self.swapButton.enabled = YES;
    buttonText = [NSString stringWithFormat:@"Select %d Photos", selectedCount];
  }
  
  [self.swapButton setTitle:buttonText forState:UIControlStateNormal];
}

#pragma mark - SelectPhotosController Delegate

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
    selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  [self configureNavTitle];
  [self configureDoneButtonText];
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
