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

@end

@implementation DFCardsPageViewController
@synthesize inviteAdapter = _inviteAdapter;
@synthesize noSuggestionsViewController = _noSuggestionsViewController;
@synthesize noIncomingViewController = _noIncomingViewController;

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
  self.view.backgroundColor = [UIColor clearColor];
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
  nextController = [self pageViewController:self
                            viewControllerAfterViewController:self.viewControllers.firstObject];
  if (!nextController) nextController = [self pageViewController:self
                              viewControllerBeforeViewController:self.viewControllers.firstObject];
  if (nextController) {
    [self setViewControllers:@[nextController]
                   direction:UIPageViewControllerNavigationDirectionForward
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
  DFOutgoingCardViewController *currentController = pageViewController.viewControllers.firstObject;
  
  NSUInteger numShown = self.alreadyShownPhotoIds.count;
  const NSUInteger UpsellCardFrequency = 5;
  if (numShown > 0 && numShown % (UpsellCardFrequency - 1) == 0) {
    UIViewController *nextUpsell = [self nextOutgoingUpsellWithStoredSuggestion:currentController.suggestionFeedObject
                                                                    storedPhoto:currentController.photoFeedObject];
    if (nextUpsell) return nextUpsell;
  }
  
  DFOutgoingCardViewController *vc = [self nextViewControllerAscending:YES
                                                    fromViewController:currentController];
  if (vc) return vc;
  return [self nextOutgoingUpsellWithStoredSuggestion:currentController.suggestionFeedObject
                                          storedPhoto:currentController.photoFeedObject];
}


- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  DFOutgoingCardViewController *vc = [self nextViewControllerAscending:NO
                                                    fromViewController:pageViewController.viewControllers.firstObject];
  if (vc) return vc;
  return nil;
}

- (DFOutgoingCardViewController *)nextViewControllerAscending:(BOOL)ascending
                                         fromViewController:(DFOutgoingCardViewController *)svc
{
  // figure out which suggestion/photo we were on
  DFPeanutFeedObject *suggestion = svc.suggestionFeedObject;
  NSArray *suggestionPhotos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
  DFPeanutFeedObject *photo = svc.photoFeedObject;
  
  // figure out the next suggestion/photo to show
  DFPeanutFeedObject *nextSuggestionToShow;
  DFPeanutFeedObject *nextPhotoToShow;
  
  // if there is a current suggestion and photo, look at the suggestion first
  if (suggestion && photo) {
    // see if there are other photos in the current suggestion
    DFPeanutFeedObject *nextPhotoInSuggestion = [suggestionPhotos
                                                 objectWithDistance:ascending ? 1 : -1
                                                 fromObject:photo
                                                 wrap:NO];
    if (nextPhotoInSuggestion) {
      nextPhotoToShow = nextPhotoInSuggestion;
      nextSuggestionToShow = suggestion;
    }
  } else {
    // otherwise, set the next photo and suggestion to the first
    NSArray *allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
    nextSuggestionToShow = [allSuggestions firstObject];
    nextPhotoToShow = [[nextSuggestionToShow leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  }
  
  // if we haven't picked a next photo to show, look at the next suggestion
  if (!nextPhotoToShow) {
    NSArray *allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
    DFPeanutFeedObject *nextSuggestionInAllSuggestions = [allSuggestions
                                                          objectWithDistance:ascending ? 1 : -1
                                                          fromObject:suggestion
                                                          wrap:NO
                                                          ];
    if (nextSuggestionInAllSuggestions) {
      nextPhotoToShow = [[nextSuggestionInAllSuggestions leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
      nextSuggestionToShow = nextSuggestionInAllSuggestions;
    }
  }
  
  // if we found a next photo and suggestion, return a VC for it
  if (nextPhotoToShow && nextSuggestionToShow) {
    DFOutgoingCardViewController *nextVC = [[DFOutgoingCardViewController alloc] init];
    nextVC.view.frame = self.view.bounds;
    
    [nextVC configureWithSuggestion:nextSuggestionToShow withPhoto:nextPhotoToShow];
    NSArray *lastSentForStrand = self.sentContactsByStrandID[nextSuggestionToShow.strand_id];
    if (lastSentForStrand.count > 0) nextVC.selectedPeanutContacts = lastSentForStrand;
    DFCardsPageViewController __weak *weakSelf = self;
    
    nextVC.yesButtonHandler = ^(DFPeanutFeedObject *suggestion,
                                NSArray *contacts,
                                NSString *caption){
      [weakSelf suggestionSelected:suggestion contacts:contacts photo:nextPhotoToShow caption:caption];
    };
    nextVC.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
      [weakSelf photoSkipped:nextPhotoToShow];
    };
    return nextVC;
  }
  return nil;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    DFOutgoingCardViewController *ovc = self.viewControllers.firstObject;
    [self.alreadyShownPhotoIds addObject:@(ovc.photoFeedObject.id)];
  }
}

- (UIViewController *)nextOutgoingUpsellWithStoredSuggestion:(DFPeanutFeedObject *)suggestion
                                                 storedPhoto:(DFPeanutFeedObject *)photo
{
  return nil;
  DFCardsPageViewController __weak *weakSelf = self;
  if (![[DFBackgroundLocationManager sharedManager] isPermssionGranted]
      && ![DFDefaultsStore lastDateForAction:DFUserActionLocationUpsellProcessed]) {
    DFUpsellCardViewController *locationUpsellController = [[DFUpsellCardViewController alloc]
                                                            initWithType:DFUpsellCardViewBackgroundLocation];
    locationUpsellController.suggestionFeedObject = suggestion;
    locationUpsellController.photoFeedObject = photo;
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
  
  [self.alreadyShownPhotoIds addObject:@(photo.id)];
  self.sentContactsByStrandID[suggestion.strand_id] = [contacts copy];
  
  [DFCreateShareInstanceController
   createShareInstanceWithPhotos:@[photo]
   fromSuggestion:suggestion
   inviteContacts:contacts
   addCaption:caption
   parentViewController:self
   enableOptimisticSend:YES
   uiCompleteHandler:^{
     dispatch_async(dispatch_get_main_queue(), ^{
       [self gotoNextController];
     });
   }
   success:nil
   failure:nil];
}

- (void)photoSkipped:(DFPeanutFeedObject *)photo
{
  if (photo)
    [self.alreadyShownPhotoIds addObject:@(photo.id)];
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
