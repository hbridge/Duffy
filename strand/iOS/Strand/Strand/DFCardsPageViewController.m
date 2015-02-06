//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCardsPageViewController.h"
#import "DFOutgoingCardViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNavigationController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFNoTableItemsView.h"
#import "DFUploadController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFDefaultsStore.h"
#import "DFImageManagerRequest.h"
#import "DFImageDiskCache.h"
#import "DFUpsellCardViewController.h"
#import "DFAnalytics.h"
#import "DFBackgroundLocationManager.h"
#import "DFPeanutShareInstance.h"
#import "DFCreateShareInstanceController.h"
#import "DFPhotoDetailViewController.h"
#import "DFOverlayNUXViewController.h"
#import "DFDismissableModalViewController.h"


const NSUInteger UpsellCardFrequency = 5;

@interface DFCardsPageViewController ()

@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic, retain) NSMutableDictionary *sentContactsByStrandID;

@property (retain, nonatomic) NSMutableSet *alreadyProcessedPhotoIDs;
@property (nonatomic, retain) NSMutableArray *allSuggestedItems;
@property (nonatomic, retain) NSArray *suggestedPhotos;

@end

@implementation DFCardsPageViewController

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType
{
  return [self initWithPreferredType:preferredType photoID:0 shareInstance:0];
}

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType
                              photoID:(DFPhotoIDType)photoID
                        shareInstance:(DFShareInstanceIDType)shareID
{
  self = [self init];
  if (self) {
    _preferredType = preferredType;
    _startingPhotoID = photoID;
    _startingShareInstanceID = shareID;
    _sentContactsByStrandID = [NSMutableDictionary new];
    _allSuggestedItems = [NSMutableArray new];
  }
  return self;
}

- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                options:nil];
  if (self) {
    self.dataSource = self;
    self.delegate = self;
    [self observeNotifications];
    [self configureNavAndTab];

    self.alreadyProcessedPhotoIDs = [NSMutableSet new];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)configureNavAndTab
{
  //self.navigationItem.title = @"Suggestions";
  self.tabBarItem.title = @"Suggestions";
  self.tabBarItem.image = [UIImage imageNamed:@"Assets/Icons/SwapBarButton"];
  self.tabBarItem.selectedImage = [UIImage imageNamed:@"Assets/Icons/SwapBarButtonSelected"];

  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:self
                                           action:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  self.view.backgroundColor = [UIColor clearColor];
  [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFSwapsFeed completion:nil];

  [self configureLoadingView];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    DFOverlayNUXViewController *suggestionNux = [[DFOverlayNUXViewController alloc]
                                                 initWithOverlayNUXType:DFoverlayNUXTypeSuggestions];
    [DFDismissableModalViewController presentWithRootController:suggestionNux
                                                       inParent:self
                                                backgroundStyle:DFDismissableModalViewControllerBackgroundStyleTranslucentBlack
                                                       animated:YES];
    [DFDefaultsStore setSetupStepPassed:DFSetupStepSuggestionsNux Passed:YES];
  }
}

- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSUInteger beforeCount = self.allSuggestedItems.count;
    
    // replace old photo objects with their new version from the feed,
    // or add them to the end if they didn't exist before
    NSMutableDictionary *previousPhotoIDsToItemIndices = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < self.allSuggestedItems.count; i++) {
      if (![self.allSuggestedItems[i] isKindOfClass:[DFPeanutFeedObject class]]) continue;
      DFPeanutFeedObject *photo = self.allSuggestedItems[i];
      previousPhotoIDsToItemIndices[@(photo.id)] = @(i);
    }
    NSArray *newSuggestedPhotos = [[DFPeanutFeedDataManager sharedManager]
                                   suggestedPhotosIncludeEvaled:YES];
    for (DFPeanutFeedObject *newSuggestedPhoto in newSuggestedPhotos) {
      NSNumber *previousIndex = previousPhotoIDsToItemIndices[@(newSuggestedPhoto.id)];
      if (previousIndex) {
        self.allSuggestedItems[previousIndex.unsignedIntegerValue] = newSuggestedPhoto;
      } else {
        [self.allSuggestedItems addObject:newSuggestedPhoto];
      }
    }
    
    NSUInteger afterCount = self.allSuggestedItems.count;
    
    // if we didn't have any items before, insert a sentinal number where the upsell should go
    if (beforeCount == 0 && afterCount > 0) {
      NSUInteger insertIndex = MIN(UpsellCardFrequency - 1, afterCount);
      [self.allSuggestedItems insertObject:@(insertIndex) atIndex:insertIndex];
    }
    
    if (!self.viewControllers.firstObject) {
      [self gotoNextController];
    }
    [self configureLoadingView];
    
  });
}

- (void)configureLoadingView
{
  if (self.viewControllers.count == 0) {
    if (!self.noResultsView) {
      self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    }
    [self.noResultsView setSuperView:self.view];
    if (self.allSuggestedItems.count > 0) {
      self.noResultsView.titleLabel.text = @"";
      [self.noResultsView.activityIndicator stopAnimating];
    } else {
      self.noResultsView.titleLabel.text = @"Loading...";
      [self.noResultsView.activityIndicator startAnimating];
    }
  } else {
    if (self.noResultsView) [self.noResultsView removeFromSuperview];
    self.noResultsView = nil;
  }
}


- (void)gotoNextController
{
  UIViewController *nextController;
  UIPageViewControllerNavigationDirection direction = UIPageViewControllerNavigationDirectionForward;
  nextController = [self pageViewController:self
                            viewControllerAfterViewController:self.viewControllers.firstObject];
  if (!nextController) {
    nextController = [self pageViewController:self
           viewControllerBeforeViewController:self.viewControllers.firstObject];
    direction = UIPageViewControllerNavigationDirectionReverse;
  }
  if (nextController) {
    [self setViewControllers:@[nextController]
                   direction:direction
                    animated:YES
                  completion:nil];
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

#pragma mark - Outgoing View Controllers

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  DFCardViewController *cardViewController = (DFCardViewController *)viewController;
  DFCardViewController *vc = [self nextViewControllerAscending:YES
                                                    fromViewController:cardViewController];
  return vc;
}


- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  DFCardViewController *cardViewController = (DFCardViewController *)viewController;
  DFCardViewController *vc = [self nextViewControllerAscending:NO
                                                    fromViewController:cardViewController];
  return vc;
}

- (DFCardViewController *)nextViewControllerAscending:(BOOL)ascending
                                   fromViewController:(DFCardViewController *)cvc
{
  if (!cvc) {
    return [self cardViewForItem:self.allSuggestedItems.firstObject];
  }
  
  // figure out which object we were on
  id<NSCopying, NSObject> fromSentinalValue = cvc.sentinalValue;
  
  if (fromSentinalValue) {
    NSInteger fromIndex = [self.allSuggestedItems indexOfObject:fromSentinalValue];
    if (fromIndex == NSNotFound) {
      DDLogWarn(@"%@ sentinal disappeared", self.class);
      return nil;
    }
    
    // look through neighboring objects until we find one that's valid to show
    for (NSInteger i = fromIndex + (ascending ? 1 : -1);
         (i < self.allSuggestedItems.count && i >= 0);
         (ascending ? i++ : i--)) {
      id<NSObject, NSCopying> object = [self.allSuggestedItems objectAtIndex:i];
      if ([[object class] isSubclassOfClass:[DFPeanutFeedObject class]]) {
        DFPeanutFeedObject *photo = (DFPeanutFeedObject *)object;
        if (!photo.evaluated.boolValue) {
          return [self outgoingCardViewControllerForPhoto:photo];
        }
      } else {
        DFCardViewController *cardView = [self cardViewForItem:object];
        if (cardView) return cardView;
      }
    }
  }

  return nil;
}

- (DFCardViewController *)cardViewForItem:(id<NSObject,NSCopying>)item
{
  if ([[item class] isSubclassOfClass:[DFPeanutFeedObject class]]) {
      return [self outgoingCardViewControllerForPhoto:(DFPeanutFeedObject *)item];
  } else {
    DFCardViewController *upsell = [self nextOutgoingUpsellWithSentinalValue:item];
    return upsell;
  }
  return nil;
}

- (DFOutgoingCardViewController *)outgoingCardViewControllerForPhoto:(DFPeanutFeedObject *)photo
{
  DFOutgoingCardViewController *ovc = [[DFOutgoingCardViewController alloc] init];
  ovc.view.frame = self.view.bounds;
  
  DFPeanutFeedObject *nextSuggestionToShow =
  [[DFPeanutFeedDataManager sharedManager] suggestedStrandForSuggestedPhoto:photo];
  [ovc configureWithSuggestion:nextSuggestionToShow withPhoto:photo];
  NSArray *lastSentForStrand = self.sentContactsByStrandID[nextSuggestionToShow.strand_id];
  if (lastSentForStrand.count > 0) ovc.selectedPeanutContacts = lastSentForStrand;
  DFCardsPageViewController __weak *weakSelf = self;
  
  ovc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion,
                              NSArray *contacts,
                              NSString *caption){
    [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo caption:caption];
  };
  ovc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
    [weakSelf photoSkipped:photo];
  };
  return ovc;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    DFCardViewController *cvc = self.viewControllers.firstObject;
    if ([cvc isKindOfClass:[DFOutgoingCardViewController class]]) {
      [DFAnalytics logOutgoingCardProcessedWithSuggestion:((DFOutgoingCardViewController *)cvc).suggestionFeedObject
                                                   result:@"scroll"
                                               actionType:DFAnalyticsActionTypeSwipe];
    } else {
      [DFAnalytics logOtherCardType:((DFUpsellCardViewController *)cvc).typeString
                processedWithResult:@"scroll"
                         actionType:DFAnalyticsActionTypeSwipe];
    }
  }
}

- (DFCardViewController *)nextOutgoingUpsellWithSentinalValue:(id)sentinalValue
{
  DFCardsPageViewController __weak *weakSelf = self;
  if (![[DFBackgroundLocationManager sharedManager] isPermssionGranted]
      && ![DFDefaultsStore lastDateForAction:DFUserActionLocationUpsellProcessed]) {
    DFUpsellCardViewController *locationUpsellController = [[DFUpsellCardViewController alloc]
                                                            initWithType:DFUpsellCardViewBackgroundLocation];
    locationUpsellController.sentinalValue = sentinalValue;
    locationUpsellController.yesButtonHandler = ^{
      [[DFBackgroundLocationManager sharedManager] promptForAuthorization];
      [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionLocationUpsellProcessed];
      [weakSelf gotoNextController];
    };
    locationUpsellController.noButtonHandler = ^{
      [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionLocationUpsellProcessed];
      [weakSelf gotoNextController];
    };
    
    return locationUpsellController;
  }
  
  return nil;
}

#pragma mark - Action Handlers

- (void)suggestionSelected:(DFPeanutFeedObject *)suggestion
                  contacts:(NSArray *)contacts
                     photo:(DFPeanutFeedObject *)photo
                   caption:(NSString *)caption
{
  if (!suggestion) {
    [self gotoNextController];
    return;
  }
  
  [self.alreadyProcessedPhotoIDs addObject:@(photo.id)];
  self.sentContactsByStrandID[suggestion.strand_id] = [contacts copy];
  
  [DFCreateShareInstanceController
   createShareInstanceWithPhotos:@[photo]
   fromSuggestion:suggestion
   inviteContacts:contacts
   addCaption:caption
   parentViewController:self
   enableOptimisticSend:YES
   completionHandler:^(BOOL allInvitesSent, NSError *error) {
     if (error) {
       NSString *errorString = [NSString stringWithFormat:@"Failed: %@", error.localizedDescription];
       [SVProgressHUD showErrorWithStatus:errorString];
     }
     dispatch_async(dispatch_get_main_queue(), ^{
       [self gotoNextController];
     });
   }];
}

- (void)photoSkipped:(DFPeanutFeedObject *)photo
{
  if (photo)
    [self.alreadyProcessedPhotoIDs addObject:@(photo.id)];
    [[DFPeanutFeedDataManager sharedManager]
     setHasEvaluatedPhoto:photo.id
     shareInstance:photo.share_instance.longLongValue];
  [self gotoNextController];
}

- (void)showCommentsForPhoto:(DFPhotoIDType)photo shareInstance:(DFShareInstanceIDType)shareInstance
{
  DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager] photoWithID:photo shareInstance:shareInstance];
  DFPhotoDetailViewController *pdvc = [[DFPhotoDetailViewController alloc]
                                       initWithPhotoObject:photoObject];
  [DFNavigationController presentWithRootController:pdvc
                                           inParent:self
                                withBackButtonTitle:@"Close"];
  
}

- (void)likePhoto:(DFPhotoIDType)photo shareInstance:(DFShareInstanceIDType)shareInstance
{
  [[DFPeanutFeedDataManager sharedManager]
   setLikedByUser:YES
   photo:photo
   shareInstance:shareInstance
   success:^(DFActionID actionID) {
  } failure:^(NSError *error) {
    
  }];
  [[DFPeanutFeedDataManager sharedManager] setHasEvaluatedPhoto:photo shareInstance:shareInstance];
  [SVProgressHUD showSuccessWithStatus:@"Liked!"];
  [self gotoNextController];
}



@end
