//
//  DFCreateStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandSuggestionsViewController.h"
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
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutFeedDataManager.h"
#import "DFImageStore.h"
#import "NSString+DFHelpers.h"
#import "DFStrandConstants.h"
#import "DFPeanutUserObject.h"
#import "DFInboxTableViewCell.h"
#import "UIDevice+DFHelpers.h"
#import "NSArray+DFHelpers.h"
#import "UINib+DFHelpers.h"
#import "DFCreateStrandViewController.h"

const CGFloat CreateCellWithTitleHeight = 192;
const CGFloat CreateCellTitleHeight = 20;
const CGFloat CreateCellTitleSpacing = 8;


@interface DFStrandSuggestionsViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;

@property (nonatomic, retain) DFPeanutObjectsResponse *allObjectsResponse;
@property (nonatomic, retain) NSMutableArray *suggestionObjects;
@property (nonatomic, retain) NSArray *allObjects;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;
@property (nonatomic, retain) NSTimer *refreshTimer;
@property (atomic, retain) NSTimer *showReloadButtonTimer;

@end

@implementation DFStrandSuggestionsViewController
@synthesize strandAdapter = _strandAdapter;

static DFStrandSuggestionsViewController *instance;
- (IBAction)reloadButtonPressed:(id)sender {
  [self.allTableView reloadData];
  [self.suggestedTableView reloadData];
  self.allTableView.contentOffset = CGPointZero;
  self.suggestedTableView.contentOffset = CGPointZero;
  [self setReloadButtonHidden:YES];
}

- (IBAction)segmentedControlValueChanged:(UISegmentedControl *)sender {
  //disable for now
//  if (sender.selectedSegmentIndex == 0) { // suggestions
//    self.suggestedTableView.hidden = NO;
//    self.allTableView.hidden = YES;
//  } else {
//    self.suggestedTableView.hidden = YES;
//    self.allTableView.hidden = NO;
//  }
//  
//  [self updateNoResultsLabel];
}

- (UITableView *)visibleTableView
{
  if (!self.suggestedTableView.hidden) return self.suggestedTableView;
  if (!self.allTableView.hidden) return self.allTableView;
  return nil;
}

+ (DFStrandSuggestionsViewController *)sharedViewController
{
  if (!instance) {
    instance = [[DFStrandSuggestionsViewController alloc] init];
  }
  return instance;
}

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    [self configureNavAndTab];
    [self observeNotifications];
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
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

NSString *const SuggestionWithPeopleId = @"suggestionWithPeople";
NSString *const SuggestionNoPeopleId = @"suggestionNoPeople";


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureTableView];
  [self configureReloadButton];
  [self configureSegmentView];
}

- (void)configureTableView
{
  self.cellHeightsByIdentifier = [NSMutableDictionary new];
  
  NSMutableArray *refreshControls = [NSMutableArray new];
  
  NSArray *tableViews = @[self.suggestedTableView, self.allTableView];
  for (UITableView *tableView in tableViews) {
    [tableView registerNib:[UINib nibWithNibName:@"DFSmallCardTableViewCell" bundle:nil]
    forCellReuseIdentifier:SuggestionWithPeopleId];
    [tableView registerNib:[UINib nibWithNibName:@"DFSmallCardTableViewCell" bundle:nil]
    forCellReuseIdentifier:SuggestionNoPeopleId];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(refreshFromServer)
             forControlEvents:UIControlEventValueChanged];
    
    UITableViewController *mockTVC = [[UITableViewController alloc] init];
    mockTVC.tableView = tableView;
    mockTVC.refreshControl = refreshControl;
    [refreshControls addObject:refreshControl];
    
    tableView.sectionHeaderHeight = 0.0;
    tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, tableView.bounds.size.width, 0.01f)];
    
  }
  
  self.allTableView.hidden = NO;
  self.suggestedTableView.hidden = YES;
  self.refreshControls = refreshControls;
  [self.refreshControl beginRefreshing];
}

- (UIRefreshControl *)refreshControl
{
  return self.refreshControls[self.segmentedControl.selectedSegmentIndex];
}


- (void)configureReloadButton
{
  self.reloadBackground.layer.cornerRadius = 5.0;
  self.reloadBackground.layer.masksToBounds = YES;
}

- (void)configureSegmentView
{
  // remove segment view for now
  [self.segmentWrapper removeFromSuperview];
  
  self.segmentWrapper.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  self.segmentedControl.tintColor = [DFStrandConstants defaultBarForegroundColor];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  UINavigationBar *navigationBar = self.navigationController.navigationBar;
  
  [navigationBar setBackgroundImage:[UIImage new]
                     forBarPosition:UIBarPositionAny
                         barMetrics:UIBarMetricsDefault];
  
  [navigationBar setShadowImage:[UIImage new]];
  
  [self reloadTableViews];
  [self refreshFromServer];
  if (self.navigationController.isBeingPresented) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancelPressed:)];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [self reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self.refreshTimer invalidate];
  self.refreshTimer = nil;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - UITableView Data/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[self sectionObjectsForSection:section tableView:tableView] count];
}

- (NSArray *)sectionObjectsForSection:(NSUInteger)section tableView:(UITableView *)tableView
{
  if (tableView == self.suggestedTableView) {
    return self.suggestionObjects;
  } else {
    return self.allObjects;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section tableView:tableView][indexPath.row];
  cell = [self cellWithSuggestedStrandObject:feedObject forTableView:tableView];
  
  return cell;
}

- (UITableViewCell *)cellWithSuggestedStrandObject:(DFPeanutFeedObject *)strandObject
                                      forTableView:(UITableView *)tableView
{
  DFCardTableViewCell *cell;
  if (strandObject.actors.count > 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:SuggestionWithPeopleId];
    [cell configureWithStyle:DFCardCellStyleSuggestionWithPeople | DFCardCellStyleSmall];
  } else {
    cell = [tableView dequeueReusableCellWithIdentifier:SuggestionNoPeopleId];
    [cell configureWithStyle:DFCardCellStyleSuggestionNoPeople | DFCardCellStyleSmall];
  }
  
  [self configureTextForCreateStrandCell:cell withStrand:strandObject];
  [self setLocalPhotosForCell:cell section:strandObject];
  
  // add the swipe gesture
  if (tableView == self.suggestedTableView && !cell.view3) {
    UILabel *hideLabel = [[UILabel alloc] init];
    hideLabel.text = @"Hide";
    hideLabel.textColor = [UIColor whiteColor];
    [hideLabel sizeToFit];
    [cell setSwipeGestureWithView:hideLabel
                            color:[UIColor lightGrayColor]
                             mode:MCSwipeTableViewCellModeExit
                            state:MCSwipeTableViewCellState3
                  completionBlock:[self hideCompletionBlock]];
    // the default color is the color that appears before you swipe far enough for the action
    // we set to the group tableview background color to blend in
    cell.defaultColor = [UIColor groupTableViewBackgroundColor];
    cell.delegate = self;
  }
  
  return cell;
}

- (MCSwipeCompletionBlock)hideCompletionBlock
{
  return ^(MCSwipeTableViewCell *cell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
    UITableView *tableView = [self visibleTableView];
    NSIndexPath *indexPath = [tableView indexPathForCell:cell];
    if (indexPath) {
      //Update the view locally
      [tableView beginUpdates];
      DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section tableView:tableView][indexPath.row];
      [self.suggestionObjects removeObject:feedObject];
      [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [tableView endUpdates];
      
      // Mark the strand as no longer suggestiblw with the server
      DFPeanutStrand *privateStrand = [[DFPeanutStrand alloc] init];
      privateStrand.id = @(feedObject.id);
      
      [self.strandAdapter
       performRequest:RKRequestMethodGET
       withPeanutStrand:privateStrand
       success:^(DFPeanutStrand *peanutStrand) {
         peanutStrand.suggestible = @(NO);
         
         // Put the peanut strand
         [self.strandAdapter
          performRequest:RKRequestMethodPUT withPeanutStrand:peanutStrand
          success:^(DFPeanutStrand *peanutStrand) {
            DDLogInfo(@"%@ successfully updated private strand to set visible false: %@", self.class, peanutStrand);
          } failure:^(NSError *error) {
            DDLogError(@"%@ failed to put private strand: %@, error: %@",
                       self.class, peanutStrand, error);
          }];
       } failure:^(NSError *error) {
         DDLogError(@"%@ failed to get private strand: %@, error: %@",
                    self.class, privateStrand, error);
       }];
    }
  };
}

- (void)configureTextForCreateStrandCell:(DFCardTableViewCell *)cell
                       withStrand:(DFPeanutFeedObject *)strandObject
{
  // Set the header attributes
  NSMutableString *actorString = [NSMutableString new];
    for (DFPeanutUserObject *user in strandObject.actors) {
    if (user != strandObject.actors.firstObject) [actorString appendString:@", "];
    [actorString appendString:user.display_name];
  }
  
  cell.peoplePrefixLabel.text = @"Swap with";
  cell.peopleLabel.text = actorString;
  
  // context label "Date in Location"
  NSMutableString *contextString = [NSMutableString new];
  [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandObject.time_taken
                                                                abbreviate:NO]];
  [contextString appendFormat:@" in %@", strandObject.location];
  cell.contextLabel.text = contextString;
  
  NSInteger count = strandObject.objects.count - cell.maxPhotosToShow;
  if (count > 0) {
    cell.countBadge.hidden = NO;
    cell.countBadge.text = [NSString stringWithFormat:@"+%d", (int)count];
  } else {
    cell.countBadge.hidden = YES;
  }
}

- (void)setRemotePhotosForCell:(DFCardTableViewCell *)cell
                   withSection:(DFPeanutFeedObject *)section
{
  NSMutableArray *photoIDs = [NSMutableArray new];
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in section.objects) {
    DFPeanutFeedObject *photoObject;
    if ([object.type isEqual:DFFeedObjectCluster]) {
      photoObject = object.objects.firstObject;
    } else if ([object.type isEqual:DFFeedObjectPhoto]) {
      photoObject = object;
    }
    if (photoObject) {
      [photoIDs addObject:@(photoObject.id)];
      [photos addObject:photoObject];
    }
  }
  
  cell.objects = photoIDs;
  for (DFPeanutFeedObject *photoObject in photos) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageThumbnail
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       [cell setImage:image forObject:@(photoObject.id)];
     }];
  }
}

- (void)setLocalPhotosForCell:(DFCardTableViewCell *)cell
                      section:(DFPeanutFeedObject *)section
{
  // Get the IDs of all the photos we want to show
  NSMutableArray *idsToShow = [NSMutableArray new];
  for (NSUInteger i = 0; i < MIN(cell.maxPhotosToShow, section.objects.count); i++) {
    DFPeanutFeedObject *object = section.objects[i];
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [idsToShow addObject:@(object.id)];
      
    } else if ([object.type isEqual:DFFeedObjectCluster]) {
      DFPeanutFeedObject *repObject = object.objects.firstObject;
      [idsToShow addObject:@(repObject.id)];
    }
  }
  
  // Set the images for the collection view
  cell.objects = idsToShow;
  for (NSNumber *photoID in idsToShow) {
    DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:photoID.longLongValue];
    if (photo) {
      CGFloat thumbnailSize;
      if ([UIDevice majorVersionNumber] >= 8) {
        // only use the larger thumbnails on iOS 8+, the scaling will kill perf on iOS7
        thumbnailSize = cell.collectionView.frame.size.height * [[UIScreen mainScreen] scale];
      } else {
        thumbnailSize = DFPhotoAssetDefaultThumbnailSize;
      }
        [photo.asset
         loadUIImageForThumbnailOfSize:thumbnailSize
         successBlock:^(UIImage *image) {
           [cell setImage:image forObject:photoID];
         } failureBlock:^(NSError *error) {
           DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
         }];
    }
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = [self sectionObjectsForSection:indexPath.section tableView:tableView][indexPath.row];
  NSString *identifier;
  DFCardCellStyle style = DFCardCellStyleSuggestionWithPeople;
  if ([feedObject.type isEqual:DFFeedObjectSection]) {
    if (feedObject.actors.count > 0) {
      identifier = SuggestionWithPeopleId;
      style = DFCardCellStyleSuggestionWithPeople | DFCardCellStyleSmall;
    } else {
      identifier = SuggestionNoPeopleId;
      style = DFCardCellStyleSuggestionNoPeople | DFCardCellStyleSmall;
    }
  }
  
  NSNumber *cachedHeight = self.cellHeightsByIdentifier[identifier];
  if (!cachedHeight) {
    DFCardTableViewCell *templateCell = [DFCardTableViewCell cellWithStyle:style];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[identifier] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *feedObjectsForSection = [self sectionObjectsForSection:indexPath.section tableView:tableView];
  DFPeanutFeedObject *feedObject = feedObjectsForSection[indexPath.row];
  
  DFCreateStrandViewController *createStrandController = [[DFCreateStrandViewController alloc]
                                                          initWithSuggestions:@[feedObject]];
  [self.navigationController pushViewController:createStrandController animated:YES];
}


#pragma mark - Actions

- (void)sync:(id)sender
{
  [[DFCameraRollSyncManager sharedManager] sync];
}


- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    self.allObjects = [self.dataManager privateStrands];
    [self reloadTableViews];
  });
}

- (void)refreshFromServer
{
  [self.dataManager refreshPrivatePhotosFromServer:^{
    for (UIRefreshControl *refreshControl in self.refreshControls) {
      [refreshControl endRefreshing];
    }
  }];
}

- (void)reloadTableViews
{
  [self.suggestedTableView reloadData];
  [self.allTableView reloadData];
  [self updateNoResultsLabel];
}

- (void)updateNoResultsLabel
{
  if (self.suggestionObjects.count == 0 && [self visibleTableView] == self.suggestedTableView) {
    self.noResultsLabel.hidden = NO;
    self.noResultsLabel.text = @"No Suggestions";
  } else if (self.allObjects.count == 0 && [self visibleTableView] == self.allTableView) {
    self.noResultsLabel.hidden = NO;
    self.noResultsLabel.text = @"No Photos Found";
  } else {
    self.noResultsLabel.hidden = YES;
  }
}

- (void)setReloadButtonHidden:(BOOL)hidden
{
  if (hidden) {
    if (self.reloadBackground.hidden || self.reloadBackground.alpha == 0.0) return;
    [UIView animateWithDuration:0.7 animations:^{
      self.reloadBackground.alpha = 0.0;
    } completion:^(BOOL finished) {
      self.reloadBackground.hidden = YES;
    }];
  } else {
    self.reloadBackground.hidden = NO;
    self.reloadBackground.alpha = fmax(self.reloadBackground.alpha, 0.0);
    [UIView animateWithDuration:0.7 animations:^{
      self.reloadBackground.alpha = 1.0;
    }];
  }
}

- (void)showReloadButton
{
  [self setReloadButtonHidden:NO];
  self.showReloadButtonTimer = nil;
}

- (NSDictionary *)mapIDsToIPs:(DFPeanutObjectsResponse *)response
{
  NSMutableDictionary *IDsToIPs = [NSMutableDictionary new];
  for (NSUInteger i = 0; i < response.objects.count; i++) {
    DFPeanutFeedObject *object = response.objects[i];
    NSUInteger section = (object.actors.count > 0) ? 1 : 2;
    IDsToIPs[@(object.id)] = [NSIndexPath indexPathForRow:i inSection:section];
  }
  return IDsToIPs;
}

- (NSArray *)idsOfObjectsWithMetadataChanges:(DFPeanutObjectsResponse *)oldResponse
                                 newResponse:(DFPeanutObjectsResponse *)newResponse
{
  NSDictionary *oldIDsToTitles = [self mapIDsToTitles:oldResponse];
  NSDictionary *newIDsToTitles = [self mapIDsToTitles:newResponse];
  
  NSMutableArray *idsOfChangedObjects = [NSMutableArray new];
  for (NSNumber *idNum in oldIDsToTitles.allKeys) {
    if (![oldIDsToTitles[idNum] isEqual:newIDsToTitles[idNum]]) {
      [idsOfChangedObjects addObject:idNum];
    }
  }
  return idsOfChangedObjects;
}

- (NSDictionary *)mapIDsToTitles:(DFPeanutObjectsResponse *)response
{
  NSMutableDictionary *IDsToTitles = [NSMutableDictionary new];
  for (DFPeanutFeedObject *feedObject in response.objects) {
    IDsToTitles[@(feedObject.id)] = feedObject.title;
  }
  return IDsToTitles;
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) {
    _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  }
  
  return _strandAdapter;
}

@end
