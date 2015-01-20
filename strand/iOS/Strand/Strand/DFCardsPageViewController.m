//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCardsPageViewController.h"
#import "DFOutgoingCardViewController.h"
#import "DFIncomingCardViewController.h"
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

@interface DFCardsPageViewController ()

@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic, readonly, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (nonatomic, retain) NSMutableDictionary *sentContactsByStrandID;

@property (nonatomic) NSInteger photoIndex;
@property (retain, nonatomic) NSMutableArray *indexPaths;

@property (retain, nonatomic) NSMutableSet *alreadyShownPhotoIds;
@property (nonatomic, retain) UIViewController *noSuggestionsViewController;
@property (nonatomic, retain) DFUpsellCardViewController *noIncomingViewController;
@property (nonatomic) NSUInteger highestSeenNuxStep;

@end

const NSUInteger NumIncomingNuxes = 1;
const NSUInteger NumOutgoingNuxes = 3;

@implementation DFCardsPageViewController
@synthesize inviteAdapter = _inviteAdapter;
@synthesize noSuggestionsViewController = _noSuggestionsViewController;
@synthesize noIncomingViewController = _noIncomingViewController;

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType
{
  return [self initWithPreferredType:preferredType photoID:0 shareInstance:0];
}

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType photoID:(DFPhotoIDType)photoID shareInstance:(DFShareInstanceIDType)shareID
{
  self = [self init];
  if (self) {
    _preferredType = preferredType;
    _startingPhotoID = photoID;
    _startingShareInstanceID = shareID;
    _sentContactsByStrandID = [NSMutableDictionary new];
  }
  return self;
}

- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationVertical
                                options:nil];
  if (self) {
    self.delegate = self;
    [self observeNotifications];
    [self configureNavAndTab];

    self.alreadyShownPhotoIds = [NSMutableSet new];
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
  self.view.backgroundColor = [DFStrandConstants cardPagerBackground];
  [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshSwapsFromServer:nil];

  [self configureLoadingView];
}

- (void)reloadData
{
  UIViewController *currentViewController = self.viewControllers.firstObject;
  if (!currentViewController || currentViewController == self.noSuggestionsViewController) {
    [self gotoNextController];
  }
  [self configureLoadingView];
}

- (void)configureLoadingView
{
  if (self.viewControllers.count == 0) {
    if (!self.noResultsView) {
      self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    }
    [self.noResultsView setSuperView:self.view];
    if ([[DFPeanutFeedDataManager sharedManager] areSuggestionsReady]) {
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
  
  BOOL incomingNuxPassed = [DFDefaultsStore isSetupStepPassed:DFSetupStepIncomingNux];
  BOOL outgoingNuxPassed =[DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux];
  
  if (! incomingNuxPassed
      && self.preferredType == DFIncomingViewType
      && self.highestSeenNuxStep < NumIncomingNuxes) {
    nextController = [self viewControllerForNuxStep:self.highestSeenNuxStep];
  } else if (!outgoingNuxPassed
             && self.preferredType == DFSuggestionViewType
             && self.highestSeenNuxStep < NumOutgoingNuxes) {
    nextController = [self viewControllerForNuxStep:self.highestSeenNuxStep];
  } else {
    nextController = [self nextOutgoingViewController];
  }
  
  if (!nextController) {
    [self dismissViewControllerAnimated:YES completion:^(){}];
    return;
  } 
  
  [self setViewControllers:@[nextController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:YES
                completion:nil];
}

#pragma mark - Outgoing View Controllers

- (UIViewController *)nextOutgoingViewController
{
  NSArray *allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  for (DFPeanutFeedObject *suggestion in allSuggestions) {
    if (!self.userToFilter || (self.userToFilter && [suggestion.actors containsObject:self.userToFilter])) {
      
      NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
      for (int x=0; x < photos.count; x++) {
        DFPeanutFeedObject *photo = photos[x];
        if (![self.alreadyShownPhotoIds containsObject:@(photo.id)] && !photo.evaluated.boolValue) {
          [self.alreadyShownPhotoIds addObject:@(photo.id)];
          DFOutgoingCardViewController *svc = [[DFOutgoingCardViewController alloc] init];
          svc.view.frame = self.view.bounds;
          
          [svc configureWithSuggestion:suggestion withPhoto:photo];
          NSArray *lastSentForStrand = self.sentContactsByStrandID[suggestion.strand_id];
          if (lastSentForStrand.count > 0) svc.selectedPeanutContacts = lastSentForStrand;
          DFCardsPageViewController __weak *weakSelf = self;

          svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion,
                                   NSArray *contacts,
                                   NSString *caption){
            [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo caption:caption];
          };
          svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
            [weakSelf photoSkipped:photo];
          };
          return svc;
        }
      }
    }
  }
  
  // we didn't find an outgoing, return an upsell if there's valid one
  return [self nextOutgoingUpsell];
}

- (UIViewController *)nextOutgoingUpsell
{
  DFCardsPageViewController __weak *weakSelf = self;
  if (![[DFBackgroundLocationManager sharedManager] isPermssionGranted]
      && ![DFDefaultsStore lastDateForAction:DFUserActionLocationUpsellProcessed]) {
    DFUpsellCardViewController *locationUpsellController = [[DFUpsellCardViewController alloc]
                                                            initWithType:DFUpsellCardViewBackgroundLocation];
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

#pragma mark - NUX and Special Cards

- (DFCardViewController *)viewControllerForNuxStep:(NSUInteger)index
{
  DFCardViewController *nuxController;
  if (self.preferredType == DFSuggestionViewType){
    DFOutgoingCardViewController *svc = [[DFOutgoingCardViewController alloc]
                                               initWithNuxStep:index + 1];
    nuxController = svc;
    if (index == 0) {
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts, NSString *caption){
        [self gotoNextController];
      };
    } else if (index == 1) {
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts, NSString *caption){
        [SVProgressHUD showSuccessWithStatus:@"Thanks!"];
        [self gotoNextController];
      };
      svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion) {
        [SVProgressHUD showErrorWithStatus:@"Tap Send to continue"];
      };
    } else if (index == 2) {
      svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
        [SVProgressHUD showSuccessWithStatus:@"On to your photos!"];
        [self gotoNextController];
        [DFDefaultsStore setSetupStepPassed:DFSetupStepSuggestionsNux Passed:YES];
      };
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts, NSString *caption){
        [SVProgressHUD showErrorWithStatus:@"Tap Skip to continue"];
      };
    }
  }
  
  self.highestSeenNuxStep++;
  return nuxController;
}

- (UIViewController *)noSuggestionsViewController
{
  if (!_noSuggestionsViewController) {
  _noSuggestionsViewController = [[UIViewController alloc] init];
    DFNoTableItemsView *noSuggestionsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    noSuggestionsView.titleLabel.textColor = [UIColor whiteColor];
    noSuggestionsView.subtitleLabel.textColor = [UIColor whiteColor];

    if (self.preferredType == DFSuggestionViewType) {
      noSuggestionsView.titleLabel.text = @"No More Suggestions";
      noSuggestionsView.subtitleLabel.text = @"Take more photos or invite more friends.";
    } else {
      noSuggestionsView.titleLabel.text = @"No More Photos in Your Inbox";
      noSuggestionsView.subtitleLabel.text = @"";
    }
    noSuggestionsView.superView = _noSuggestionsViewController.view;
  }
  return _noSuggestionsViewController;
}

- (UIViewController *)noIncomingViewController
{
  
  if (!_noIncomingViewController) {
    _noIncomingViewController = [[DFUpsellCardViewController alloc] init];
    DFCardsPageViewController __weak *weakSelf = self;
    
    _noIncomingViewController.yesButtonHandler = ^() {
      weakSelf.preferredType = DFSuggestionViewType;
      [weakSelf gotoNextController];
    };
    
    _noIncomingViewController.noButtonHandler = ^() {
      [weakSelf dismissViewControllerAnimated:YES completion:^(){}];
    };
  }
  return _noIncomingViewController;
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
  
  self.sentContactsByStrandID[suggestion.strand_id] = [contacts copy];
  
  [DFCreateShareInstanceController
   createShareInstanceWithPhoto:photo
   fromSuggestion:suggestion
   inviteContacts:contacts
   addCaption:caption
   parentViewController:self
   uiCompleteHandler:^{
     [self gotoNextController];
   }
   success:nil
   failure:nil];
}

- (void)photoSkipped:(DFPeanutFeedObject *)photo
{
  if (photo)
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
   oldActionID:0
   success:^(DFActionID actionID) {
    
  } failure:^(NSError *error) {
    
  }];
  [[DFPeanutFeedDataManager sharedManager] setHasEvaluatedPhoto:photo shareInstance:shareInstance];
  [SVProgressHUD showSuccessWithStatus:@"Liked!"];
  [self gotoNextController];
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}


@end
