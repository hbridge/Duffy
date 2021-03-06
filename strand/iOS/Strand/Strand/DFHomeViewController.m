//
//  DFHomeViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFHomeViewController.h"
#import "DFCardsPageViewController.h"
#import "DFNavigationController.h"
#import "DFDefaultsStore.h"
#import "DFPushNotificationsManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNoTableItemsView.h"
#import "DFSettingsViewController.h"
#import "UIColor+DFHelpers.h"
#import "DFSegmentedControlReusableView.h"
#import "DFLabelReusableView.h"
#import "DFPhotoDetailViewController.h"
#import "DFFriendsViewController.h"
#import "DFPeanutNotificationsManager.h"
#import "DFDismissableModalViewController.h"
#import "DFAnalytics.h"
#import "DFMultiPhotoDetailPageController.h"
#import <WYPopoverController/WYPopoverController.h>
#import "DFBadgeButton.h"
#import "UIView+DFExtensions.h"
#import "UIImageEffects.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFFriendProfileViewController.h"
#import "DFAlertController.h"

const CGFloat ExpandedNavBarHeight = 19 + 44 + 87;
const CGFloat CollapsedNavBarHeight = 19 + 44;
const NSUInteger MinPhotosToShowFilter = 20;

@interface DFHomeViewController ()

@property (nonatomic, retain) DFImageDataSource *datasource;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic) NSUInteger selectedFilterIndex;
@property (nonatomic, retain) MMPopLabel *suggestionsNuxPopLabel;
@property (nonatomic, retain) MMPopLabel *cameraRollNuxPopLabel;
@property (nonatomic, retain) DFNotificationsViewController *notificationsViewController;
@property (nonatomic, retain) WYPopoverController *notificationsPopupController;
@property (nonatomic, retain) DFBadgeButton *notificationsBadgeButton;
@property (nonatomic) BOOL suggestionsAreaHidden;
@property (nonatomic, retain) UIImageView *navBackgroundImageView;
@property (nonatomic, retain) UIButton *createButton;

@end

@implementation DFHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.buttonBar.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  self.numPhotosPerRow = 3;
  [self observeNotifications];
  [self configureNav];
  [self configureCollectionView];
  [self configureNoResultsView];
  [self configureNUXPopLabels];
  [self reloadData];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNotificationsUpdatedNotification
                                             object:nil];
  
}

- (void)configureNav
{
  self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
  self.navigationController.navigationBar.translucent = YES;
  self.navigationController.navigationBar.barTintColor = [UIColor clearColor];
  
  self.buttonBar.gradientDirection = SAMGradientViewDirectionHorizontal;
  
  self.notificationsBadgeButton = [[DFBadgeButton alloc] init];
  [self.notificationsBadgeButton setImage:[[UIImage imageNamed:@"Assets/Icons/NotificationsBarButton"]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                 forState:UIControlStateNormal];
  [self.notificationsBadgeButton addTarget:self
                                    action:@selector(notificationsButtonPressed:)
                          forControlEvents:UIControlEventTouchUpInside];
  self.notificationsBadgeButton.badgeColor = [DFStrandConstants strandRed];
  self.notificationsBadgeButton.badgeTextColor = [UIColor whiteColor];
  self.notificationsBadgeButton.badgeEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
  [self.notificationsBadgeButton sizeToFit];
  
  self.createButton = [[UIButton alloc] init];
  [self.createButton setImage:[[UIImage imageNamed:@"Assets/Icons/AddPhotosBarButton"]
                               imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                     forState:UIControlStateNormal];
  [self.createButton addTarget:self
                        action:@selector(createButtonPressed:)
              forControlEvents:UIControlEventTouchUpInside];
  [self.createButton sizeToFit];
  
  self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc]
                                               initWithCustomView:self.notificationsBadgeButton],
                                              [[UIBarButtonItem alloc]
                                               initWithCustomView:self.createButton],
                                              ];
  self.navigationItem.leftBarButtonItems = @[
                                             [[UIBarButtonItem alloc]
                                              initWithImage:[UIImage imageNamed:@"Assets/Icons/PeopleNavBarButton"]
                                              style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(friendsButtonPressed:)],
                                             ];
  [self setSuggestionsAreaHidden:YES animated:NO completion:nil];
  
  [self addNavBlur];
}

- (void)addNavBlur
{
  self.navBackgroundImageView = [[UIImageView alloc] init];
  self.navBackgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.buttonBar insertSubview:self.navBackgroundImageView atIndex:0];
  [self.navBackgroundImageView constrainToSuperviewSize];
  self.navBackgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)configureCollectionView
{
  self.datasource = [[DFImageDataSource alloc]
                     initWithSections:nil
                     collectionView:self.collectionView];
  self.datasource.imageDataSourceDelegate = self;
  self.collectionView.delegate = self;
  
  [self.collectionView registerNib:[UINib nibForClass:[DFSegmentedControlReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"segmentedHeader"];
  [self.collectionView registerNib:[UINib nibForClass:[DFLabelReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"labelHeader"];
  [self.collectionView registerNib:[UINib nibForClass:[DFLabelReusableView class]]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footer"];
  //self.flowLayout.footerReferenceSize = CGSizeMake(self.collectionView.frame.size.width, headerHeight);

  self.datasource.showActionsBadge = YES;
  self.datasource.showUnreadNotifsCount = YES;
  self.collectionView.backgroundColor = [UIColor whiteColor];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  if (kind == UICollectionElementKindSectionHeader) {
    return [self headerViewForIndexPath:indexPath];
  } else if (kind == UICollectionElementKindSectionFooter) {
    return [self footerViewForIndexPath:indexPath];
  }
  
  [NSException raise:@"unexpected type" format:@"unexpected supplementary view type type"];
  return nil;
}

static BOOL showFilters = NO;

- (UICollectionReusableView *)headerViewForIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *reusableView = nil;
  if (showFilters) {
    DFSegmentedControlReusableView *segmentedView =
    [self.collectionView
     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
     withReuseIdentifier:@"segmentedHeader"
     forIndexPath:indexPath];
    reusableView = segmentedView;
    [segmentedView.segmentedControl setTitle:@"Liked & Commented" forSegmentAtIndex:0];
    [segmentedView.segmentedControl setTitle:@"All Photos" forSegmentAtIndex:1];
    [segmentedView.segmentedControl setWidth:140 forSegmentAtIndex:0];
    [segmentedView.segmentedControl setWidth:140 forSegmentAtIndex:1];
    segmentedView.segmentedControl.tintColor = [UIColor colorWithRedByte:35 green:35 blue:35 alpha:1.0];
    [segmentedView.segmentedControl addTarget:self
                                       action:@selector(filterChanged:)
                             forControlEvents:UIControlEventValueChanged];
  } else {
    DFLabelReusableView *labelHeader = [self.collectionView
     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
     withReuseIdentifier:@"labelHeader"
     forIndexPath:indexPath];
    reusableView =  labelHeader;
    labelHeader.label.textAlignment = NSTextAlignmentCenter;
    labelHeader.label.textColor = [UIColor lightGrayColor];
    DFSection *section = self.datasource.sections[indexPath.section];
    labelHeader.label.text = section.title;
  }
  
  if (!reusableView) [NSException raise:@"null header" format:@"null header"];
  
  return reusableView;
}

- (UICollectionReusableView *)footerViewForIndexPath:(NSIndexPath *)indexPath
{
  DFLabelReusableView *footerView = [self.collectionView
                                     dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                     withReuseIdentifier:@"footer"
                                     forIndexPath:indexPath];
  UILabel *footerLabel = footerView.label;

  footerLabel.font = [UIFont fontWithName:@"HelvetiaNeue" size:19.0];
  footerLabel.textColor = [UIColor lightGrayColor];
  footerLabel.textAlignment = NSTextAlignmentCenter;
  
  if ([[self.datasource photosForSection:indexPath.section] count] == 0) {
    footerLabel.text = @"No Photos";
  } else {
    footerLabel.text = @"";
  }
  
  return footerView;
}


- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource
{
  
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadNavData];
  [[DFPeanutFeedDataManager sharedManager] refreshAllFeedsFromServer];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if ([DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]
      || [DFDefaultsStore isSetupStepPassed:DFSetupStepSendCameraRoll]) {
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
  }
  [self reloadNavData];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [self.suggestionsNuxPopLabel dismiss];
  [self.cameraRollNuxPopLabel dismiss];
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
  dispatch_async(dispatch_get_main_queue(), ^{
    if (showFilters) {
      NSArray *feedPhotos;

      if (self.selectedFilterIndex == 0) {
        feedPhotos = [[DFPeanutFeedDataManager sharedManager] photosWithActivity];
      } else {
        feedPhotos = [[DFPeanutFeedDataManager sharedManager]
                      allPhotos];
      }
      [self.datasource setFeedPhotos:feedPhotos];
    } else {
      NSArray *allPhotos = [[DFPeanutFeedDataManager sharedManager]
                            allPhotos];
      NSArray *sections = [self.class sectionsFromFeedPhotos:allPhotos];
      [self.datasource setSections:sections];
    }
    
    [self configureNoResultsView];
    [self reloadNavData];
  });
}

+ (NSArray *)sectionsFromFeedPhotos:(NSArray *)feedPhotos
{
  if (feedPhotos.count > 0)
    return @[[DFSection sectionWithTitle:@"All Photos" object:nil rows:feedPhotos]];
  return @[];
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

- (void)configureNUXPopLabels
{
  self.suggestionsNuxPopLabel = [MMPopLabel
                           popLabelWithText:@"Share photos fast"];
  [self.view addSubview:self.suggestionsNuxPopLabel];
  self.cameraRollNuxPopLabel = [MMPopLabel popLabelWithText:@"Send a photo to a friend"];
  self.cameraRollNuxPopLabel.delegate = self;
  [self.view addSubview:self.cameraRollNuxPopLabel];
}

- (void)reloadNavData
{
  self.sendButton.layer.cornerRadius = 3;
  self.sendButton.layer.masksToBounds = YES;
  self.sendBadgeView.badgeColor = [DFStrandConstants strandRed];
  self.sendBadgeView.textColor = [UIColor whiteColor];
  
  NSUInteger unreadNotifications = [[[DFPeanutNotificationsManager sharedManager] unreadNotifications] count];
  self.notificationsBadgeButton.badgeCount = (int)unreadNotifications;
  
  [self reloadSuggestionsArea];
}

- (void)reloadSuggestionsArea
{
  NSArray *suggestedPhotos = [[DFPeanutFeedDataManager sharedManager] suggestedPhotosIncludeEvaled:NO];
  NSUInteger numToSend = [suggestedPhotos count];
  
  
  self.sendBadgeView.hidden = YES;
  self.sendBadgeView.text = [@(MIN(numToSend, 99)) stringValue];
  DFPeanutFeedObject *firstPhotoToSend = [suggestedPhotos firstObject];
  [self setNavAreaForSuggestedPhoto:firstPhotoToSend];
  DFHomeViewController __weak *weakSelf = self;
  [self setSuggestionsAreaHidden:NO animated:NO completion:^{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]
          && [[DFPeanutFeedDataManager sharedManager] suggestedPhotosIncludeEvaled:NO] > 0
          && (!weakSelf.hasShownSuggestionsNux
              || [[[DFPeanutFeedDataManager sharedManager] photosWithEvaluated:NO] count] == 0)
          && weakSelf.view.window){
        [weakSelf.suggestionsNuxPopLabel
         popAtView:weakSelf.sendButton
         animatePopLabel:YES
         animateTargetView:NO];
        weakSelf.hasShownSuggestionsNux = YES;
      }
      [weakSelf.cameraRollNuxPopLabel dismiss];
    });
  }];
}

- (void)setNavAreaForSuggestedPhoto:(DFPeanutFeedObject *)suggestedPhoto
{
  if (suggestedPhoto) {
    [[DFImageManager sharedManager]
     imageForID:suggestedPhoto.id
     pointSize:self.sendButton.frame.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         self.sendButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
         self.sendButton.backgroundColor = [UIColor clearColor];
         [self.sendButton setImage:image
                          forState:UIControlStateNormal];
         UIColor *tintColor = [UIColor colorWithWhite:0.97 alpha:0.7];
         self.navBackgroundImageView.image = [UIImageEffects imageByApplyingBlurToImage:image
                                                                             withRadius:60
                                                                              tintColor:tintColor
                                                                  saturationDeltaFactor:2.0
                                                                              maskImage:nil];
         
     });
   }];
  } else {
    self.navBackgroundImageView.image = nil;
    [self.sendButton setImage:[UIImage imageNamed:@"Assets/Icons/HomeSend"] forState:UIControlStateNormal];
    [self.sendButton setBackgroundImage:[UIImage imageNamed:@"Assets/Icons/HomeSendHighlighted"]
                               forState:UIControlStateNormal];
    self.buttonBar.gradientColors = [DFStrandConstants homeNavBarGradientColors];
  }
}



- (void)setSuggestionsAreaHidden:(BOOL)suggestionsAreaHidden
{
  [self setSuggestionsAreaHidden:suggestionsAreaHidden animated:NO completion:nil];
}

- (void)setSuggestionsAreaHidden:(BOOL)hidden animated:(BOOL)animated completion:(DFVoidBlock)completion
{
  if (hidden && !_suggestionsAreaHidden) {
    // hide the suggestions area
    [self.sendButton setBackgroundImage:nil
                               forState:UIControlStateNormal];
    self.navBackgroundImageView.image = nil;
    self.buttonBarHeightConstraint.constant = CollapsedNavBarHeight;
    [UIView animateWithDuration:animated ? 0.5 : 0.0 animations:^{
      for (UIView *view in @[self.sendButton, self.buttonBarLabel]) {
        view.alpha = 0.0;
      }
      self.sendBadgeView.hidden = YES;
      [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
      if (finished && completion) completion();
    }];
    self.buttonBar.gradientColors = [DFStrandConstants homeNavBarGradientColors];
    self.navigationItem.title = @"Swap";
    [self.suggestionsNuxPopLabel dismiss];
  } else if (!hidden && _suggestionsAreaHidden){
    //show the suggestions area
    self.buttonBarHeightConstraint.constant = ExpandedNavBarHeight;
    [UIView animateWithDuration:animated ? 0.5 : 0.0 animations:^{
      for (UIView *view in @[self.sendButton, self.buttonBarLabel]) {
        view.alpha = 1.0;
      }
      [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
      if (finished && completion) completion();
    }];
    self.buttonBar.gradientColors = @[
                                      [UIColor whiteColor]
                                      ];
    self.navigationItem.title = nil;
  } else {
    if (completion) completion();
  }
  _suggestionsAreaHidden = hidden;
}

#pragma mark - Actions

- (IBAction)sendButtonPressed:(id)sender {
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  if (numToSend > 0 || ![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    [DFDismissableModalViewController
     presentWithRootController:[[DFCardsPageViewController alloc]
                                initWithPreferredType:DFSuggestionViewType]
     inParent:self];
  }
  [self logHomeButtonPressed:sender];
  
  // handle nux
  [DFDefaultsStore setSetupStepPassed:DFSetupStepSuggestionsNux Passed:YES];
  [self.suggestionsNuxPopLabel dismiss];
}

- (void)logHomeButtonPressed:(id)button
{
  NSString *buttonName = @"";
  if (button == self.sendButton) buttonName = @"outgoing";
  NSUInteger numToSend = [[[DFPeanutFeedDataManager sharedManager] suggestedStrands] count];
  [DFAnalytics logHomeButtonTapped:buttonName
                incomingBadgeCount:0
                outgoingBadgeCount:numToSend];
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *photo = [[[self.datasource feedObjectForIndexPath:indexPath]
                                leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  DDLogVerbose(@"%@ photo:%@ share_instance:%@ tapped", self.class, @(photo.id), photo.share_instance);
  [self showMultiPhotoControllerWithStartingPhoto:photo];
}

- (void)showMultiPhotoControllerWithStartingPhoto:(DFPeanutFeedObject *)photo
{
  NSMutableArray *allPhotos = [NSMutableArray new];
  for (NSUInteger section = 0; section < [self.datasource numberOfSectionsInCollectionView:self.collectionView]; section++) {
    [allPhotos addObjectsFromArray:[self.datasource photosForSection:section]];
  }
  DFMultiPhotoDetailPageController *mpvc = [[DFMultiPhotoDetailPageController alloc]
                                            initWithCurrentPhoto:photo inPhotos:allPhotos];
  
  [DFDismissableModalViewController presentWithRootController:mpvc inParent:self];
}

- (void)filterChanged:(UISegmentedControl *)sender
{
  DDLogVerbose(@"new filter %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
  self.selectedFilterIndex = sender.selectedSegmentIndex;
}

- (void)setSelectedFilterIndex:(NSUInteger)selectedFilterIndex
{
  _selectedFilterIndex = selectedFilterIndex;
  [self reloadData];
}

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
  [DFDefaultsStore setSetupStepPassed:DFSetupStepSendCameraRoll Passed:YES];
  [self.cameraRollNuxPopLabel dismiss];
}


static DFPeanutFeedObject *currentPhoto;
- (void)settingsPressed:(id)sender
{
  [DFSettingsViewController presentModallyInViewController:self];
}

- (void)testCycleBackgroundArea
{
  NSArray *suggestedPhotos = [[DFPeanutFeedDataManager sharedManager] suggestedPhotosIncludeEvaled:NO];
  if (!currentPhoto) {
    currentPhoto = suggestedPhotos.firstObject;
  }
  
  currentPhoto = [suggestedPhotos objectAfterObject:currentPhoto wrap:YES];
  [self setNavAreaForSuggestedPhoto:currentPhoto];
}

- (void)friendsButtonPressed:(id)sender
{
  DFFriendsViewController *friendsViewController = [[DFFriendsViewController alloc] init];
  [DFNavigationController presentWithRootController:friendsViewController
                                           inParent:self
                                withBackButtonTitle:@"Close"];
}

- (void)notificationsButtonPressed:(DFBadgeButton *)sender
{
  WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
  appearance.fillTopColor = [UIColor whiteColor];
  if (!self.notificationsViewController) {
    self.notificationsViewController = [[DFNotificationsViewController alloc] init];
    self.notificationsViewController.delegate = self;
    self.notificationsPopupController = [[WYPopoverController alloc]
                                         initWithContentViewController:self.notificationsViewController];
  }
  
  if (self.notificationsPopupController.isPopoverVisible) {
    [self.notificationsPopupController dismissPopoverAnimated:YES];
  } else {
    [self.notificationsPopupController presentPopoverFromRect:sender.frame
                                                       inView:sender.superview
                                     permittedArrowDirections:WYPopoverArrowDirectionUp
                                                     animated:YES
                                                      options:WYPopoverAnimationOptionFadeWithScale
                                                   completion:nil];
  }
}

- (void)notificationViewController:(DFNotificationsViewController *)notificationViewController
   didSelectNotificationWithAction:(DFPeanutAction *)peanutAction
{
  [self.notificationsPopupController dismissPopoverAnimated:YES];
  if (peanutAction.action_type == DFPeanutActionSuggestedPhoto ||
      peanutAction.action_type == DFPeanutActionRequestPhotos) {
    DFPeanutFeedObject *suggestedPhoto;
    for (DFPeanutFeedObject *photo in [[DFPeanutFeedDataManager sharedManager]
                                       suggestedPhotosIncludeEvaled:NO]) {
      if (photo.id == peanutAction.photo.longLongValue) {
        suggestedPhoto = photo;
        break;
      }
    }
    if (suggestedPhoto) {
      DFCardsPageViewController *cardsPVC = [[DFCardsPageViewController alloc]
                                             initWithPreferredType:DFSuggestionViewType
                                             startingPhoto:suggestedPhoto];
      [DFDismissableModalViewController presentWithRootController:cardsPVC inParent:self];
    } else {
      [SVProgressHUD showSuccessWithStatus:@"Photo already processed"];
    }
  } else if (peanutAction.action_type == DFPeanutActionAddedAsFriend) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:peanutAction.user];
    
    DFFriendProfileViewController *friendProfile = [[DFFriendProfileViewController alloc]
                                                    initWithPeanutUser:user];
    [self.navigationController pushViewController:friendProfile animated:YES];
  } else if (peanutAction.action_type == DFPeanutActionCanRequestPhotos) {
    [self requestPhotos:peanutAction.strand.longLongValue user:peanutAction.user];
  } else {
    DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager]
                                       photoWithID:peanutAction.photo.longLongValue
                                       shareInstance:peanutAction.share_instance.longLongValue];
    [self showMultiPhotoControllerWithStartingPhoto:photoObject];
  }
}

- (void)requestPhotos:(DFStrandIDType)strandID user:(DFUserIDType)userID
{
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:userID];
  NSString *messageString = [NSString stringWithFormat:@"Request photos from %@?", user.fullName];
  DFAlertController *requestAlert = [DFAlertController
                                     alertControllerWithTitle:@"Request Photos"
                                     message:messageString
                                     preferredStyle:DFAlertControllerStyleAlert];
  [requestAlert
   addAction:[DFAlertAction
              actionWithTitle:@"Cancel"
              style:DFAlertActionStyleCancel
              handler:^(DFAlertAction *action) {
                [DFAnalytics logPhotoRequestInitiatedWithResult:DFAnalyticsValueResultAborted];
              }]];
  [requestAlert
   addAction:[DFAlertAction
              actionWithTitle:@"Request"
              style:DFAlertActionStyleDefault
              handler:^(DFAlertAction *action) {
                [[DFPeanutFeedDataManager sharedManager]
                 requestPhotos:strandID fromUser:userID
                 success:^{
                   [DFAnalytics logPhotoRequestInitiatedWithResult:@"Requested"];
                   [SVProgressHUD showSuccessWithStatus:@"Request Sent!"];
                 } failure:^(NSError *error) {
                   [DFAnalytics logPhotoRequestInitiatedWithResult:DFAnalyticsValueResultFailure];
                   [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:@"Error: %@",
                                                         error.localizedDescription]];
                 }];
              }]];
  [requestAlert showWithParentViewController:self animated:YES completion:nil];
}

- (void)dismissedPopLabel:(MMPopLabel *)popLabel
{
  if (popLabel == self.cameraRollNuxPopLabel
      && self.suggestionsNuxPopLabel.hidden) {
    [DFDefaultsStore setSetupStepPassed:DFSetupStepSendCameraRoll Passed:YES];
  }
}



@end
