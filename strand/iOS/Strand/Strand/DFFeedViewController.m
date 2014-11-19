//
//  DFPhotoFeedController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFeedViewController.h"
#import "DFAnalytics.h"
#import "DFDefaultsStore.h"
#import "DFFeedSectionHeaderView.h"
#import "DFImageManager.h"
#import "DFNavigationController.h"
#import "DFNotificationSharedConstants.h"
#import "DFPeanutActionAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoFeedCell.h"
#import "DFPhotoMetadataAdapter.h"
#import "DFPhotoStore.h"
#import "DFStrandConstants.h"
#import "DFUploadController.h"
#import "DFUploadingFeedCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSString+DFHelpers.h"
#import "UIAlertView+DFHelpers.h"
#import "DFInviteStrandViewController.h"
#import "DFStrandGalleryTitleView.h"
#import "NSIndexPath+DFHelpers.h"
#import "DFSwapUpsellView.h"
#import "UINib+DFHelpers.h"
#import "DFReviewSwapViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "NSArray+DFHelpers.h"
#import "DFStrandPeopleBarView.h"
#import "SVProgressHUD.h"
#import "DFImageManager.h"
#import "DFStrandPeopleViewController.h"
#import "DFCommentViewController.h"

const CGFloat SectionHeaderHeight = 51.0;
static int ImagePrefetchRange = 3;

@interface DFFeedViewController ()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;
@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;

@property (nonatomic) DFPhotoIDType actionSheetPhotoID;
@property (nonatomic) DFPhotoIDType requestedPhotoIDToJumpTo;

@property (nonatomic) CGFloat previousScrollViewYOffset;
@property (nonatomic) BOOL isViewTransitioning;

@property (readonly, nonatomic, retain) NSDictionary *photoIndexPathsById;
@property (readonly, nonatomic, retain) NSDictionary *photoObjectsById;
@property (readonly, nonatomic, retain) NSMutableDictionary *rowHeights;
@property (nonatomic, retain) NSMutableDictionary *templateCellsByStyle;
@property (nonatomic, retain) DFSwapUpsellView *swapUpsellView;

@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;
@property (nonatomic, retain) DFPeanutFeedObject *postsObject;
@property (nonatomic, retain) DFPeanutFeedObject *suggestionsObject;

@property (nonatomic, retain) NSTimer *refreshTimer;
@property (nonatomic, retain) DFStrandPeopleBarView *peopleBar;
@property (nonatomic, retain) DFStrandGalleryTitleView *titleView;

@end

@implementation DFFeedViewController

@synthesize photoAdapter = _photoAdapter;

- (instancetype)initWithFeedObject:(DFPeanutFeedObject *)feedObject
{
  self = [super init];
  if (self) {
    _rowHeights = [NSMutableDictionary new];
    _templateCellsByStyle = [NSMutableDictionary new];
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
    [self observeNotifications];
    
    [self initTabBarItem];
    [self initNavItem];
    
    if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
      self.inviteObject = feedObject;
      self.postsObject = [[feedObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
      self.suggestionsObject = [[feedObject subobjectsOfType:DFFeedObjectSuggestedPhotos] firstObject];
      
      // This is for if we come through a notification
      if (self.inviteObject.objects.count == 0) {
        [SVProgressHUD showWithStatus:@"Loading..."];
        [self reloadData];
      }
      
      [self setStrandActionsEnabled:NO];
    } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]
               || [feedObject.type isEqual:DFFeedObjectSection]) {
      self.inviteObject = nil;
      self.postsObject = feedObject;

      if (self.postsObject.objects.count == 0) {
        [SVProgressHUD showWithStatus:@"Loading..."];
        [self reloadData];
      }
    } else if ([feedObject.type isEqual:DFFeedObjectStrand]) {
      self.inviteObject = nil;
      DFPeanutFeedObject *postsObject = [feedObject copy];
      postsObject.actors = feedObject.actors;
      postsObject.objects = @[feedObject];
      self.postsObject = postsObject;
    }
  }
  return self;
}


/*
 * This is the same code as in DFCreateStrandFlowViewController, might want to abstract if we do this more
 */
+ (DFFeedViewController *)presentFeedObject:(DFPeanutFeedObject *)feedObject
  modallyInViewController:(UIViewController *)viewController
{
  DFFeedViewController *feedViewController = [[DFFeedViewController alloc]
                                              initWithFeedObject:feedObject];
  DFNavigationController *navController = [[DFNavigationController alloc] initWithRootViewController:feedViewController];
  feedViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                          initWithImage:[UIImage imageNamed:@"Assets/Icons/BackNavButton"]
                                                         style:UIBarButtonItemStylePlain
                                                         target:feedViewController
                                                          action:@selector(dismissWhenPresented)];
  
  [viewController presentViewController:navController animated:YES completion:nil];
  return feedViewController;
}

- (void)dismissWhenPresented
{
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


/*
 * Reload data from the data manager.  We're using the strand id we were init'd with.
 */
- (void)reloadData
{
  DDLogVerbose(@"%@ told to reload my data...", self.class);
  _rowHeights = [NSMutableDictionary new];
  if (self.inviteObject) {
    // We might not have the invite in the feed yet (might have come through notification
    //   So if that happens, don't overwrite our current one which has the id
    DFPeanutFeedObject *invite = [self.dataManager inviteObjectWithId:self.inviteObject.id];
  
    if (invite) {
      self.inviteObject = invite;
      self.suggestionsObject = [[self.inviteObject subobjectsOfType:DFFeedObjectSuggestedPhotos] firstObject];
      self.postsObject = [[self.inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
      
      if ([self.inviteObject.ready isEqual:@(YES)]) {
        [SVProgressHUD dismiss];
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
        
        // If we're currently showing the matching activity but now our invite is ready, then
        //   turn off the timer and show the upsell result
        if ([self.swapUpsellView isMatchingActivityOn]) {
          [self.swapUpsellView configureActivityWithVisibility:NO];
          [self showUpsellResult];
        }
      }
      [self.swapUpsellView reloadDataWithInviteObject:invite];
    }
  } else {
    DFPeanutFeedObject *posts = [self.dataManager strandPostsObjectWithId:self.postsObject.id];
    
    // We might not have the postsObject in the feed yet (might have come through notification
    //   So if that happens, don't overwrite our current one which has the id
    if (posts) {
      self.postsObject = posts;
    }
  }
  
  [self.peopleBar configureWithStrandPostsObject:self.postsObject];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)initTabBarItem
{
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)initNavItem
{
  self.navigationItem.rightBarButtonItems =
  @[[[UIBarButtonItem alloc]
     initWithImage:[UIImage imageNamed:@"Assets/Icons/PhotosBarButton"]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(addPhotosButtonPressed:)],
    [[UIBarButtonItem alloc]
     initWithImage:[UIImage imageNamed:@"Assets/Icons/PeopleNavBarButton"]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(peopleButtonPressed:)],
    ];
  
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Back"
                                           style:UIBarButtonItemStylePlain
                                           target:self
                                           action:nil];
}

- (void)setStrandActionsEnabled:(BOOL)enabled
{
  for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) {
    item.enabled = enabled;
  }
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)refreshFromServer
{
  [self.dataManager refreshInboxFromServer:^{
    [self reloadData];
  }];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self configureTitleView];
  [self configureTableView];
  [self configureUpsell];
}

- (void)configureTitleView
{
  if (!self.titleView) {
    self.titleView =
    [[[UINib nibWithNibName:NSStringFromClass([DFStrandGalleryTitleView class])
                     bundle:nil]
      instantiateWithOwner:nil options:nil]
     firstObject];
    self.navigationItem.titleView = self.titleView;
  }
  
  if (self.postsObject.location) {
    self.titleView.locationLabel.text = self.postsObject.location;
  } else {
    [self.titleView.locationLabel removeFromSuperview];
  }
  self.titleView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:self.postsObject.time_taken
                                                                    abbreviate:NO];
}

- (void)configureTableView
{
  self.tableView.scrollsToTop = YES;

  NSMutableArray *styles = [NSMutableArray new];
  for (DFPhotoFeedCellAspect aspect = DFPhotoFeedCellAspectSquare; aspect <= DFPhotoFeedCellAspectLandscape; aspect++) {
    for (DFPhotoFeedCellStyle style = DFPhotoFeedCellStyleNone;
         style <= (DFPhotoFeedCellStyleCollectionVisible
                   | DFPhotoFeedCellStyleHasComments
                   | DFPhotoFeedCellStyleHasLikes);
         style++) {
      [styles addObject:[self identifierForCellStyle:style aspect:aspect]];
    }
  }
  
  for (NSString *style in styles) {
    [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
         forCellReuseIdentifier:style];
  }
  
  [self.tableView
   registerNib:[UINib nibWithNibName:@"DFFeedSectionHeaderView"
                              bundle:nil]
   forHeaderFooterViewReuseIdentifier:@"sectionHeader"];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  DFPhotoFeedCell *templateCell = [self templateCellWithStyle:DFPhotoFeedCellStyleNone
                                                       aspect:DFPhotoFeedCellAspectLandscape];
  self.tableView.rowHeight = [templateCell.contentView
                              systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;

}
- (void)configureUpsell
{
  if (self.inviteObject) {
    // if this is an invite create an upsell if necessary and add it
    if (!self.swapUpsellView) {
      self.swapUpsellView = [UINib instantiateViewWithClass:[DFSwapUpsellView class]];
      [self.view addSubview:self.swapUpsellView];
      [self configureUpsellHeight];
      
      [self.swapUpsellView configureWithInviteObject:self.inviteObject
                                           buttonTarget:self
                                               selector:@selector(upsellButtonPressed:)];
    }
    
    if ([self.inviteObject.ready isEqual:@(YES)]) {
      [self.swapUpsellView configureActivityWithVisibility:NO];
    }
  } else {
    [self.swapUpsellView removeFromSuperview];
  }
}

- (void)configureUpsellHeight
{
  CGFloat swapUpsellHeight = MIN(self.view.frame.size.height * .7 + self.tableView.contentOffset.y,
                                 self.tableView.frame.size.height);
  swapUpsellHeight = MAX(swapUpsellHeight, DFUpsellMinHeight);
  self.swapUpsellView.frame = CGRectMake(0,
                                         self.view.frame.size.height - swapUpsellHeight,
                                         self.view.frame.size.width,
                                         swapUpsellHeight);
}

- (NSString *)identifierForCellStyle:(DFPhotoFeedCellStyle)style
                              aspect:(DFPhotoFeedCellAspect)aspect
{
  return [NSString stringWithFormat:@"%d%d", (int)style, (int)aspect];
}

- (void)viewWillAppear:(BOOL)animated
{
  self.isViewTransitioning = YES;
  [super viewWillAppear:animated];
  [self configureUpsell];
  
  if (self.inviteObject && (!self.inviteObject.ready || [self.inviteObject.ready isEqual:@(NO)])) {
    DDLogVerbose(@"%@ Invite not ready, setting up timer...", self.class);
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:.5
                                                         target:self
                                                       selector:@selector(refreshFromServer)
                                                       userInfo:nil
                                                        repeats:YES];
  } else {
    DDLogVerbose(@"%@ showing view but I think that I don't need a timer %@  %@",
                 self.class,
                 self.inviteObject,
                 self.inviteObject.ready);
  }
  
  if (self.onViewScrollToPhotoId) {
    DDLogVerbose(@"Scrolling to photo %llu", self.onViewScrollToPhotoId);
    [self showPhoto:self.onViewScrollToPhotoId animated:NO];
    self.onViewScrollToPhotoId = 0;
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  self.isViewTransitioning = NO;
  [super viewDidAppear:animated];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  
  NSString *type = self.inviteObject ? @"invite" : @"non-invite";
  [DFAnalytics logViewController:self appearedWithParameters:@{@"type" : type}];
}

- (void)viewWillDisappear:(BOOL)animated
{
  self.isViewTransitioning = YES;
  [super viewWillDisappear:animated];
  
  if (self.refreshTimer) {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
  }
  [SVProgressHUD dismiss];
}

- (void)viewDidDisappear:(BOOL)animated
{
  self.isViewTransitioning = NO;
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self configureUpsell];
}

- (void)setPostsObject:(DFPeanutFeedObject *)strandPostsObject
{
  _postsObject = strandPostsObject;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self configureTitleView];
    NSMutableDictionary *objectsByID = [NSMutableDictionary new];
    NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
    
    for (NSUInteger sectionIndex = 0; sectionIndex < self.postsObject.objects.count; sectionIndex++) {
      NSArray *objectsForSection = [self.postsObject.objects[sectionIndex] objects];
      for (NSUInteger objectIndex = 0; objectIndex < objectsForSection.count; objectIndex++) {
        DFPeanutFeedObject *object = objectsForSection[objectIndex];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:objectIndex inSection:sectionIndex];
        if ([object.type isEqual:DFFeedObjectPhoto]) {
          objectsByID[@(object.id)] = object;
          indexPathsByID[@(object.id)] = indexPath;
        } else if ([object.type isEqual:DFFeedObjectCluster]) {
          for (DFPeanutFeedObject *subObject in object.objects) {
            objectsByID[@(subObject.id)] = subObject;
            indexPathsByID[@(subObject.id)] = indexPath;
          }
        }
      }
    }
    
    _photoObjectsById = objectsByID;
    _photoIndexPathsById = indexPathsByID;
    
    [self.tableView reloadData];
  });
}


#pragma mark - Jump to a specific photo

- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *indexPath = self.photoIndexPathsById[@(photoId)];
   
    if (indexPath) {
      // set isViewTransitioning to prevent the nav bar from disappearing from the scroll
      self.isViewTransitioning = YES;
      [self.tableView scrollToRowAtIndexPath:indexPath
                            atScrollPosition:UITableViewScrollPositionTop
                                    animated:animated];
      
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isViewTransitioning = NO;
      });
    } else {
      DDLogWarn(@"%@ showPhoto:%llu no indexPath for photoId found.",
                [self.class description],
                photoId);
    }
  });
}

#pragma mark - Table view data source: sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.postsObject.objects.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  if (self.showPersonPerPhoto) return nil;
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"sectionHeader"];
 
  DFPeanutFeedObject *strandPost = [self strandPostObjectForSection:section];
  headerView.actorLabel.text = [strandPost actorsString];
  headerView.profilePhotoStackView.peanutUsers = strandPost.actors;
  headerView.actionTextLabel.text = strandPost.title;
  headerView.subtitleLabel.text = [NSDateFormatter relativeTimeStringSinceDate:strandPost.time_stamp abbreviate:NO];
  headerView.representativeObject = strandPost;
  headerView.delegate = self;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if (self.showPersonPerPhoto) return 0;
  return SectionHeaderHeight;
}



#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  DFPeanutFeedObject *strandPost = [self strandPostObjectForSection:section];
  
  NSArray *items = strandPost.objects;
  return items.count;
}

- (DFPeanutFeedObject *)strandPostObjectForSection:(NSUInteger)tableSection
{
  return self.postsObject.objects[tableSection];
}

- (DFPeanutFeedObject *)objectAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *strandPost = [self strandPostObjectForSection:indexPath.section];
  if (indexPath.row >= 0 && indexPath.row < strandPost.objects.count)
    return strandPost.objects[indexPath.row];
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  DFPeanutFeedObject *object = [self objectAtIndexPath:indexPath];
  cell = [self cellForFeedObject:object indexPath:indexPath];
  
  if (!cell) {
    [NSException raise:@"nil cell" format:@"nil cell for object: %@", object];
  }
  
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  [cell setNeedsLayout];

  [self prefetchImagesAroundIndexPath:indexPath];
  return cell;
}

- (DFPhotoFeedCell *)cellForFeedObject:(DFPeanutFeedObject *)feedObject
                           indexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCellStyle style = [self cellStyleForIndexPath:indexPath];
  DFPhotoFeedCellAspect aspect = [self aspectForIndexPath:indexPath];
  DFPhotoFeedCell *photoFeedCell = [self.tableView
                                    dequeueReusableCellWithIdentifier:[self identifierForCellStyle:style
                                                                                            aspect:aspect]
                                    forIndexPath:indexPath];
  [photoFeedCell configureWithStyle:style aspect:aspect];
  photoFeedCell.delegate = self;
  
  [photoFeedCell setAuthor:[self.postsObject actorWithID:feedObject.user]];
  [photoFeedCell setComments:[feedObject actionsOfType:DFPeanutActionComment forUser:0]];
  [photoFeedCell setLikes:[feedObject actionsOfType:DFPeanutActionFavorite forUser:0]];
  
  NSArray *photoIDs;
  if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
    photoIDs = @[@(feedObject.id)];
  } else {
    photoIDs = [feedObject.objects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *object) {
      return @(object.id);
    }];
  }
  
  if (![photoIDs isEqualToArray:photoFeedCell.objects]) {
    // if the objects on the cell were the same as previous, no need to reset the objects
    // which will cause it to clear the images and flicker
    [photoFeedCell setObjects:photoIDs];
  }
  if (photoIDs.count > 0) {
    for (NSNumber *photoID in photoIDs) {
      [[DFImageManager sharedManager]
       imageForID:photoID.longLongValue
       size:[self imageSizeToFetch]
       contentMode:DFImageRequestContentModeAspectFit
       deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
       completion:^(UIImage *image) {
         dispatch_async(dispatch_get_main_queue(), ^{
           if (![self.tableView.visibleCells containsObject:photoFeedCell]) return;
           [photoFeedCell setImage:image forObject:photoID];
           [photoFeedCell setNeedsLayout];
         });
       }];
    }
  }
  
  return photoFeedCell;
}


- (void)prefetchImagesAroundIndexPath:(NSIndexPath *)indexPath
{
  NSMutableArray *idsToFetch = [NSMutableArray new];
  for (NSInteger i = indexPath.row + ImagePrefetchRange; i >= indexPath.row - ImagePrefetchRange; i--){
    DFPeanutFeedObject *object = [self objectAtIndexPath:[NSIndexPath
                                                          indexPathForRow:i
                                                          inSection:indexPath.section]];
    if (!object) continue;
    if ([object.type isEqual:DFFeedObjectCluster]) object = object.objects.firstObject;
    [idsToFetch addObject:@(object.id)];
  }
  
  [[DFImageManager sharedManager] startCachingImagesForPhotoIDs:idsToFetch
                                                     targetSize:[self imageSizeToFetch]
                                                    contentMode:DFImageRequestContentModeAspectFit];
}

- (CGSize)imageSizeToFetch
{
  CGFloat imageViewHeight = [DFPhotoFeedCell
                             imageViewHeightForReferenceWidth:[[UIScreen mainScreen] bounds].size.width
                             aspect:DFPhotoFeedCellAspectPortrait];
  CGFloat scale = [[UIScreen mainScreen] scale];
  return CGSizeMake(imageViewHeight * scale, imageViewHeight * scale);
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *cachedHeight = self.rowHeights[[indexPath dictKey]];
  if (cachedHeight) return cachedHeight.floatValue;
  
  DFPhotoFeedCellStyle style = [self cellStyleForIndexPath:indexPath];
  DFPhotoFeedCellAspect aspect = [self aspectForIndexPath:indexPath];
  DFPhotoFeedCell *templateCell = [self templateCellWithStyle:style aspect:aspect];
  if (style & DFPhotoFeedCellStyleHasComments || style & DFPhotoFeedCellStyleHasLikes) {
    //to get an accurate height for cells with comments/likes, we have to actually set the data
    DFPeanutFeedObject *object = [self objectAtIndexPath:indexPath];
    [templateCell setComments:[object actionsOfType:DFPeanutActionComment forUser:0]];
    [templateCell setLikes:[object actionsOfType:DFPeanutActionFavorite forUser:0]];
  }
  
  CGFloat rowHeight = [templateCell rowHeight];
  
  [self setHeight:rowHeight forRowAtIndexPath:indexPath];
  return rowHeight;
}

- (DFPhotoFeedCell *)templateCellWithStyle:(DFPhotoFeedCellStyle)style aspect:(DFPhotoFeedCellAspect)aspect
{
  DFPhotoFeedCell *cell = self.templateCellsByStyle[@(style)];
  if (!cell) {
    cell = [DFPhotoFeedCell createCellWithStyle:style aspect:aspect];
    CGRect frame = cell.frame;
    frame.size.width = self.view.frame.size.width;
    cell.frame = frame;
    [cell layoutIfNeeded];
  }
  return cell;
}

- (DFPhotoFeedCellStyle)cellStyleForIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCellStyle style = DFPhotoFeedCellStyleNone;
  DFPeanutFeedObject *object = [self objectAtIndexPath:indexPath];
  DFPeanutFeedObject *photoObject = object;
  if ([object.type isEqual:DFFeedObjectCluster]) {
    photoObject = object.objects.firstObject;
    style |= DFPhotoFeedCellStyleCollectionVisible;
  }
  if ([[photoObject actionsOfType:DFPeanutActionComment forUser:0] count] > 0) {
    style |= DFPhotoFeedCellStyleHasComments;
  }
  if ([[photoObject actionsOfType:DFPeanutActionFavorite forUser:0] count] > 0) {
    style |= DFPhotoFeedCellStyleHasLikes;
  }
  
  if (self.showPersonPerPhoto) {
    style |= DFPhotoFeedCellStyleShowAuthor;
  }
  
  return style;
}

- (DFPhotoFeedCellAspect)aspectForIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCellAspect aspect = DFPhotoFeedCellAspectSquare;
  DFPeanutFeedObject *object = [self objectAtIndexPath:indexPath];
  DFPeanutFeedObject *photoObject = object;
  if (photoObject.full_height.intValue > photoObject.full_width.intValue) {
    aspect = DFPhotoFeedCellAspectPortrait;
  } else if (photoObject.full_height.intValue < photoObject.full_width.intValue) {
    aspect = DFPhotoFeedCellAspectLandscape;
  } else {
    aspect = DFPhotoFeedCellAspectSquare;
  }
  return aspect;
}

- (void)setHeight:(CGFloat)height forRowAtIndexPath:(NSIndexPath *)indexPath
{
  self.rowHeights[[indexPath dictKey]] = @(height);
}

#pragma mark - Actions


- (void)showUpsellResult
{
  DFPeanutFeedObject *postsObject = [[self.inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  if (self.suggestionsObject.objects.count == 0) {
    [UIAlertView
     showSimpleAlertWithTitle:@"No Matches"
     formatMessage:@"You have no photos with %@ from %@. Enjoy your free photos!",
     [self.inviteObject actorsString],
     [postsObject placeAndRelativeTimeString]
     ];
    [[DFPeanutFeedDataManager sharedManager]
     acceptInvite:self.inviteObject
     addPhotoIDs:nil
     success:^{
       self.swapUpsellView.hidden = YES;
       [self.swapUpsellView removeFromSuperview];
       self.inviteObject = nil;
       [self setStrandActionsEnabled:YES];
     } failure:^(NSError *error) {
     }];
    [DFAnalytics
     logMatchPhotos:self.inviteObject
     withMatchedPhotos:nil
     selectedPhotos:nil
     result:DFAnalyticsValueResultSuccess];
  } else {
    DFReviewSwapViewController *addPhotosController = [[DFReviewSwapViewController alloc]
                                                      initWithSuggestions:self.suggestionsObject.objects
                                                      invite:self.inviteObject
                                                      swapSuccessful:^{
                                                        // Now that we've successfull swapped...turn our view
                                                        //   into a regular view from an invite
                                                        self.inviteObject = nil;
                                                        [self setStrandActionsEnabled:YES];
                                                      }];
    DFNavigationController *navController = [[DFNavigationController alloc]
                                             initWithRootViewController:addPhotosController];
    addPhotosController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                            target:self
                                                            action:@selector(dismissMatch:)];
    [self presentViewController:navController animated:YES completion:nil];
  }
}

- (void)upsellButtonPressed:(id)sender
{
  [self.swapUpsellView configureActivityWithVisibility:YES];
  
  if ([self.inviteObject.ready isEqual:@(YES)]) {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    DDLogVerbose(@"Invite ready, showing in .5 second");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self showUpsellResult];
    });
  } else {
    // If we're not ready, the timer is running and it will show the matched area once the invite is ready
    DDLogVerbose(@"Invite not ready, relying upon timer");
  }
}

- (void)dismissMatch:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
  NSArray *suggestions = [self.inviteObject subobjectsOfType:DFFeedObjectSuggestedPhotos];
  [DFAnalytics
   logMatchPhotos:self.inviteObject
   withMatchedPhotos:[DFPeanutFeedObject leafObjectsOfType:DFFeedObjectPhoto
                                      inArrayOfFeedObjects:suggestions]
   selectedPhotos:nil
   result:DFAnalyticsValueResultAborted];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *object = [self objectAtIndexPath:indexPath];
  
  DDLogVerbose(@"Row tapped for object: %@", object);
               
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - DFFeedSectionHeaderView Delegate

- (void)inviteButtonPressedForHeaderView:(DFFeedSectionHeaderView *)headerView
{
  DFPeanutFeedObject *section = (DFPeanutFeedObject *)headerView.representativeObject;
  DFInviteStrandViewController *vc = [[DFInviteStrandViewController alloc] init];
  vc.sectionObject = section;
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:vc]
                     animated:YES
                   completion:nil];
}

#pragma mark - DFPhotoFeedCell Delegates



- (void)commentButtonPressedForObject:(id)object sender:(id)sender
{
  NSNumber *photoID = (NSNumber *)object;
  
  DFPeanutFeedObject *photoObject = [self.postsObject firstPhotoWithID:photoID.longLongValue];
  DDLogVerbose(@"Comment button for %@ pressed", photoObject);
  DFCommentViewController *cvc = [[DFCommentViewController alloc]
                                  initWithPhotoObject:photoObject
                                  inPostsObject:self.postsObject];
  [self.navigationController pushViewController:cvc animated:YES];
}

- (void)addComment:(NSNumber *)objectIDNumber commentString:(NSString *)commentString sender:(id)sender
{
  DDLogVerbose(@"Comment added");
  DFPhotoIDType photoID = [objectIDNumber longLongValue];
  
  DFPeanutAction *commentAction;
  commentAction = [[DFPeanutAction alloc] init];
  commentAction.user = [[DFUser currentUser] userID];
  commentAction.action_type = DFPeanutActionComment;
  commentAction.photo = photoID;
  commentAction.strand = self.postsObject.id;
  commentAction.text = commentString;
  
  DFPeanutActionAdapter *adapter = [[DFPeanutActionAdapter alloc] init];
  [adapter addAction:commentAction success:nil failure:nil];
}


/* DISABLED FOR NOW*/
- (void)favoriteButtonPressedForObject:(NSNumber *)objectIDNumber sender:(id)sender
{
  DDLogVerbose(@"Favorite button pressed");
  DFPhotoIDType photoID = [objectIDNumber longLongValue];
  NSIndexPath *indexPath = self.photoIndexPathsById[@(photoID)];
  DFPeanutFeedObject *photoObject = self.photoObjectsById[objectIDNumber];
  DFPeanutAction *oldFavoriteAction = [[photoObject actionsOfType:DFPeanutActionFavorite
                                             forUser:[[DFUser currentUser] userID]]
                               firstObject];
  //BOOL wasGesture = [sender isKindOfClass:[UIGestureRecognizer class]];
  DFPeanutAction *newAction;
  if (!oldFavoriteAction) {
    newAction = [[DFPeanutAction alloc] init];
    newAction.user = [[DFUser currentUser] userID];
    newAction.action_type = DFPeanutActionFavorite;
    newAction.photo = photoID;
    newAction.strand = self.postsObject.id;
  } else {
    newAction = nil;
  }
  
  [photoObject setUserFavoriteAction:newAction];
  
  [self.rowHeights removeObjectForKey:[indexPath dictKey]];
  [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
  
  RKRequestMethod method;
  DFPeanutAction *action;
  if (!oldFavoriteAction) {
    method = RKRequestMethodPOST;
    action = newAction;
  } else {
    method = RKRequestMethodDELETE;
    action = oldFavoriteAction;
  }
  
  DFPeanutActionAdapter *adapter = [[DFPeanutActionAdapter alloc] init];
  [adapter
   performRequest:method
   withPath:ActionBasePath
   objects:@[action]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     DFPeanutAction *action = resultObjects.firstObject;
     if (action) {
       [photoObject setUserFavoriteAction:action];
     } // no need for the else case, it was already removed optimistically
     
     [DFAnalytics
      logPhotoActionTaken:DFPeanutActionFavorite
      result:DFAnalyticsValueResultSuccess
      photoObject:photoObject
      postsObject:self.postsObject
      ];
   } failure:^(NSError *error) {
     [photoObject setUserFavoriteAction:oldFavoriteAction];
     [self reloadRowForPhotoID:photoID];
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                     message:error.localizedDescription
                                                    delegate:nil
                                           cancelButtonTitle:@"OK"
                                           otherButtonTitles:nil];
     [alert show];
     [DFAnalytics
      logPhotoActionTaken:DFPeanutActionFavorite
      result:DFAnalyticsValueResultFailure
      photoObject:photoObject
      postsObject:self.postsObject
      ];
   }];

}

- (void)moreOptionsButtonPressedForObject:(NSNumber *)objectIDNumber sender:(id)sender
{
  DDLogVerbose(@"More options button pressed");
  DFPhotoIDType objectId = [objectIDNumber longLongValue];
  DFPeanutFeedObject *object = self.photoObjectsById[objectIDNumber];
  self.actionSheetPhotoID = objectId;
  
  NSString *deleteTitle = [self isObjectDeletableByUser:object] ? @"Delete" : nil;

  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:deleteTitle
                                                  otherButtonTitles:@"Save", nil];
  
  [actionSheet showInView:self.tableView];
}


- (void)feedCell:(DFPhotoFeedCell *)feedCell
selectedObjectChanged:(id)newObject
      fromObject:(id)oldObject
{
  DDLogVerbose(@"feedCell object changed from: %@ to %@", oldObject, newObject);
  [feedCell setNeedsLayout];
}




#pragma mark - Action Handler Helpers

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);
  if ([buttonTitle isEqualToString:@"Delete"]) {
    [self confirmDeletePhoto];
  } else if ([buttonTitle isEqualToString:@"Save"]) {
    [self savePhotoToCameraRoll];
  }
}

- (BOOL)isObjectDeletableByUser:(DFPeanutFeedObject *)object
{
  return object.user == [[DFUser currentUser] userID];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 1) {
    [self deletePhoto];
  }
}

- (void)confirmDeletePhoto
{
  UIAlertView *alertView = [[UIAlertView alloc]
                            initWithTitle:@"Delete Photo?"
                            message:@"You and other strand users will no longer be able to see it."
                            delegate:self
                            cancelButtonTitle:@"Cancel"
                            otherButtonTitles:@"Delete", nil];
  [alertView show];
}

- (void)deletePhoto
{
  DFPeanutFeedObject *photoObject = self.photoObjectsById[@(self.actionSheetPhotoID)];
  [[DFPeanutFeedDataManager sharedManager] removePhoto:photoObject fromStrandPosts:self.postsObject success:^{
    [self removePhotoObjectFromView:photoObject];
    [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultSuccess
                    timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:photoObject.time_taken]];
  } failure:^(NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      NSString *message = [NSString stringWithFormat:@"Sorry, an error occurred: %@",
                            error.localizedRecoverySuggestion ?
                            error.localizedRecoverySuggestion : error.localizedDescription];
      message = [message substringToIndex:MIN(200, message.length)];
      [UIAlertView
       showSimpleAlertWithTitle:@"Error"
       message:message];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultFailure
                      timeIntervalSinceTaken:[[NSDate date] timeIntervalSinceDate:photoObject.time_taken]];
    });
  }];
}

// Removes a photo object from the local cache of strand objects and updates the view
- (void)removePhotoObjectFromView:(DFPeanutFeedObject *)photoObject
{
  NSIndexPath *indexPath = self.photoIndexPathsById[@(self.actionSheetPhotoID)];
  DFPeanutFeedObject *strandPost = [self strandPostObjectForSection:indexPath.section];
  DFPeanutFeedObject *objectInStrand = strandPost.objects[indexPath.row];
  DFPeanutFeedObject *containingObject;
  if ([objectInStrand.type isEqual:DFFeedObjectCluster]) {
    // the object is in a cluster row
    containingObject = objectInStrand;
  } else {
    containingObject = strandPost;
  }
  
  NSMutableArray *newObjects = containingObject.objects.mutableCopy;
  [newObjects removeObject:photoObject];
  containingObject.objects = newObjects;

  dispatch_async(dispatch_get_main_queue(), ^{
    if (containingObject == strandPost) {
      // if the containing object was the strand, the entire row disappears.  animate it
      [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                            withRowAnimation:UITableViewRowAnimationFade];
    } else {
      [self.tableView reloadData];
    }
  });
}

- (void)savePhotoToCameraRoll
{
  @autoreleasepool {
    [[DFImageManager sharedManager]
     imageForID:self.actionSheetPhotoID
     preferredType:DFImageFull
     completion:^(UIImage *image) {
       if (image) {
         [self.photoAdapter
          getPhoto:self.actionSheetPhotoID
          withImageDataTypes:DFImageFull
          completionBlock:^(DFPeanutPhoto *peanutPhoto, NSDictionary *imageData, NSError *error) {
            [[DFPhotoStore sharedStore]
             saveImageToCameraRoll:image
             withMetadata:peanutPhoto.metadataDictionary
             completion:^(NSURL *assetURL, NSError *error) {
               dispatch_async(dispatch_get_main_queue(), ^{
                 if (error) {
                   [UIAlertView showSimpleAlertWithTitle:@"Error"
                                                 message:error.localizedDescription];
                   DDLogError(@"Saving photo to camera roll failed: %@", error.description);
                   [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultFailure];
                 } else {
                   DDLogInfo(@"Photo saved.");
                   
                   [UIAlertView showSimpleAlertWithTitle:nil
                                                 message:@"Photo saved to your camera roll"];
                   

                   [[NSNotificationCenter defaultCenter]
                    postNotificationName:DFStrandCameraPhotoSavedNotificationName
                    object:self];
                   [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultSuccess];
                 }});
             }];
          }];
       } else {
         dispatch_async(dispatch_get_main_queue(), ^{
           NSString *errorMessage = @"Could not download photo.";
           [UIAlertView showSimpleAlertWithTitle:@"Error" message:errorMessage];
           DDLogError(@"Failed to save photo.");
         });
       }
     }];
  }
}

- (void)reloadRowForPhotoID:(DFPhotoIDType)photoID
{
  [self.tableView reloadData];
}


- (void)peopleButtonPressed:(id)sender
{
  DFStrandPeopleViewController *peopleViewController = [[DFStrandPeopleViewController alloc]
                                                        initWithStrandPostsObject:self.postsObject];
  [self.navigationController pushViewController:peopleViewController animated:YES];
}

- (void)addPhotosButtonPressed:(id)sender
{
  NSArray *privateStrands = [[DFPeanutFeedDataManager sharedManager] privateStrandsByDateAscending:YES];
  DFSelectPhotosViewController *selectPhotosViewController = [[DFSelectPhotosViewController alloc]
                                                              initWithCollectionFeedObjects:privateStrands];
  selectPhotosViewController.navigationItem.title = @"Add Photos";
  selectPhotosViewController.actionButtonVerb = @"Add";
  selectPhotosViewController.delegate = self;
  DFNavigationController *navController = [[DFNavigationController alloc]
                                           initWithRootViewController:selectPhotosViewController];
  
  [self presentViewController:navController animated:YES completion:nil];
  
}

- (void)selectPhotosViewController:(DFSelectPhotosViewController *)controller didFinishSelectingFeedObjects:(NSArray *)selectedFeedObjects
{
  if (selectedFeedObjects.count == 0) {
    [self dismissViewControllerAnimated:YES completion:nil];
    return;
  }
  
  DFFeedViewController __weak *weakSelf = self;
  [SVProgressHUD show];
  [[DFPeanutFeedDataManager sharedManager]
   addFeedObjects:selectedFeedObjects
   toStrandPosts:self.postsObject success:^{
     NSString *status = [NSString stringWithFormat:@"Added %@ photos", @(selectedFeedObjects.count)];
     [SVProgressHUD showSuccessWithStatus:status];
     DDLogInfo(@"%@ adding %@ photos succeeded.", self.class, @(selectedFeedObjects.count));
     [weakSelf dismissViewControllerAnimated:YES completion:nil];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
     DDLogError(@"%@ adding photos failed: %@", self.class, error);
   }];
}

#pragma mark - Adapters

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  }
  
  return _photoAdapter;
}


#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (![self shouldHandleScrollChange]) return;
  CGFloat scrollOffset = scrollView.contentOffset.y;
  
  if (scrollOffset > -scrollView.contentInset.top) {
    [self configureUpsellHeight];
  }
  
  // store the scrollOffset for calculations next time around
  self.previousScrollViewYOffset = scrollOffset;
}

- (BOOL)shouldHandleScrollChange
{
  if (self.isViewTransitioning || !self.view.window) return NO;
  
  return YES;
}


@end
