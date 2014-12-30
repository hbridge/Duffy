//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionsPageViewController.h"
#import "DFSwipableSuggestionViewController.h"
#import "DFIncomingViewController.h"
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
#import "DFNoIncomingViewController.h"
#import "DFAnalytics.h"

@interface DFSuggestionsPageViewController ()

@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic, readonly, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (nonatomic, retain) NSArray *lastSentContacts;

@property (nonatomic) NSInteger photoIndex;
@property (retain, nonatomic) NSMutableArray *indexPaths;

@property (retain, nonatomic) NSMutableSet *alreadyShownPhotoIds;
@property (nonatomic, retain) UIViewController *noSuggestionsViewController;
@property (nonatomic, retain) DFNoIncomingViewController *noIncomingViewController;
@property (nonatomic) NSUInteger highestSeenNuxStep;

@end

const NSUInteger NumIncomingNuxes = 1;
const NSUInteger NumOutgoingNuxes = 3;

@implementation DFSuggestionsPageViewController
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
    if (self.preferredType == DFIncomingViewType) {
      nextController = [self nextIncomingViewController];
    } else {
      nextController = [self nextSuggestionViewController];
    }
  }
  
  if (!nextController) {
    if (self.preferredType == DFIncomingViewType && !self.viewControllers.firstObject) {
      // This actually handles the IncomingViewType, even though its named otherwise
      nextController = [self noSuggestionsViewController];
    } else if (self.preferredType == DFIncomingViewType) {
      // If we don't have any more suggestions, and we've been showing stuff, close
      [self dismissViewControllerAnimated:YES completion:^(){}];
      return;
    } else {
      nextController = [self noSuggestionsViewController];
    }
  } 
  
  [self setViewControllers:@[nextController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:YES
                completion:nil];
}

- (UIViewController *)nextIncomingViewController
{
  DFPeanutFeedObject *nextPhoto = [self nextIncomingPhotoToShow];
  if (!nextPhoto) return nil;
  
  DFIncomingViewController *ivc = [[DFIncomingViewController alloc]
                                   initWithPhotoID:nextPhoto.id
                                   shareInstance:nextPhoto.share_instance.longLongValue
                                   fromSender:[[DFPeanutFeedDataManager sharedManager]
                                               userWithID:nextPhoto.user]];
  [self.alreadyShownPhotoIds addObject:@(nextPhoto.id)];
  
  DFSuggestionsPageViewController __weak *weakSelf = self;
  ivc.nextHandler = ^(DFPhotoIDType photoID, DFShareInstanceIDType shareInstance){
    [weakSelf photoSkipped:nextPhoto];
  };
  ivc.commentHandler = ^(DFPhotoIDType photoID, DFShareInstanceIDType shareInstance){
    [weakSelf showCommentsForPhoto:photoID shareInstance:shareInstance];
  };
  ivc.likeHandler = ^(DFPhotoIDType photoID, DFShareInstanceIDType shareInstance){
    [weakSelf likePhoto:photoID shareInstance:shareInstance];
  };
  
  return ivc;

}

- (DFPeanutFeedObject *)nextIncomingPhotoToShow
{
  if ([self startingPhotoID] > 0) {
    DFPeanutFeedObject *photo = [[DFPeanutFeedDataManager sharedManager]
                                 photoWithID:[self startingPhotoID]
                                 shareInstance:[self startingShareInstanceID]];
    _startingPhotoID = 0;
    _startingShareInstanceID = 0;
    
    return photo;
  }
  
  DFPeanutFeedObject *firstPhoto;
  NSArray *photos = [[DFPeanutFeedDataManager sharedManager] unevaluatedPhotosFromOtherUsers];
  for (DFPeanutFeedObject *photo in photos) {
    //don't return photos we've already shown
    if ([self.alreadyShownPhotoIds containsObject:@(photo.id)]) continue;
    // Now lets see if the image is loaded yet
    DFImageManagerRequest *request = [[DFImageManagerRequest alloc] initWithPhotoID:photo.id imageType:DFImageFull];
    if ([[DFImageDiskCache sharedStore] canServeRequest:request]) {
      return photo;
    } else if(!firstPhoto) {
      // Keep track of the first photo incase none of our photos are loaded
      // just use this one and show the spinner
      firstPhoto = photo;
    }
  }
  
  if (firstPhoto) {
    // We didn't find any images loaded but we did have an image...so show that with a spinner
    return firstPhoto;
  } else {
    return nil;
  }
}

- (UIViewController *)nextSuggestionViewController
{
  NSArray *allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  for (DFPeanutFeedObject *suggestion in allSuggestions) {
    if (!self.userToFilter || (self.userToFilter && [suggestion.actors containsObject:self.userToFilter])) {
      
      NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
      for (int x=0; x < photos.count; x++) {
        DFPeanutFeedObject *photo = photos[x];
        if (![self.alreadyShownPhotoIds containsObject:@(photo.id)]) {
          [self.alreadyShownPhotoIds addObject:@(photo.id)];
          DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc] init];
          svc.view.frame = self.view.bounds;
          
          [svc configureWithSuggestion:suggestion withPhoto:photo];
          if (suggestion.actors.count == 0 && self.lastSentContacts.count > 0) {
            svc.selectedPeanutContacts = self.lastSentContacts;
          }
          DFSuggestionsPageViewController __weak *weakSelf = self;

          svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
            [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo];
          };
          svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
            [weakSelf photoSkipped:photo];
          };
          return svc;
        }
      }
    }
  }
  return nil;
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

/*
 * We need to return the IndexPath which corrisponds to the given view controller
 */
- (NSUInteger)indexOfViewController:(UIViewController *)viewController
{
  if (![[viewController class] isSubclassOfClass:[DFHomeSubViewController class]]) return -1;
  DFHomeSubViewController *subVC = (DFHomeSubViewController *)viewController;
  
  return subVC.index;
}

// TODO(Derek): This might not be needed anymore
- (void)updateIndexOfViewController:(UIViewController *)viewController index:(NSUInteger)index
{
  if (![[viewController class] isSubclassOfClass:[DFHomeSubViewController class]]) return;
  DFHomeSubViewController *subVC = (DFHomeSubViewController *)viewController;
  
  subVC.index = index;
}


- (NSUInteger)currentViewControllerIndex
{
  UIViewController *currentController = self.viewControllers.firstObject;
  return  [self indexOfViewController:currentController];
}

- (DFHomeSubViewController *)viewControllerForNuxStep:(NSUInteger)index
{
  DFHomeSubViewController *nuxController;
  if (index == 0 && self.preferredType == DFIncomingViewType) {
    DFIncomingViewController *ivc = [[DFIncomingViewController alloc] initWithNuxStep:1];
    nuxController = ivc;
    
    NSString *incomingCompletionString = nil;
    if ([self nextIncomingPhotoToShow]) {
      incomingCompletionString = @"Someone else sent you photos!";
    }
    DFIncomingPhotoActionHandler block = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
      if (incomingCompletionString) {
        [SVProgressHUD showSuccessWithStatus:incomingCompletionString];
      }
      [DFDefaultsStore setSetupStepPassed:DFSetupStepIncomingNux Passed:YES];
      [self gotoNextController];
    };
    
    ivc.nextHandler = block;
    ivc.likeHandler = block;
  } else if (self.preferredType == DFSuggestionViewType){
    DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc]
                                               initWithNuxStep:index + 1];
    nuxController = svc;
    if (index == 0) {
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
        [self gotoNextController];
      };
    } else if (index == 1) {
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
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
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
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
    _noIncomingViewController = [[DFNoIncomingViewController alloc] init];
    DFSuggestionsPageViewController __weak *weakSelf = self;
    
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

#pragma mark - UIPageViewController Delegate/Datasource

- (void)suggestionSelected:(DFPeanutFeedObject *)suggestion
                  contacts:(NSArray *)contacts
                     photo:(DFPeanutFeedObject *)photo
{
  if (!suggestion) {
    [self gotoNextController];
    return;
  }
  
  self.lastSentContacts = contacts;
  
  NSArray *phoneNumbers = [contacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
    return contact.phone_number;
  }];
  
  [[DFPeanutFeedDataManager sharedManager]
   sharePhotoObjects:@[photo]
   withPhoneNumbers:phoneNumbers
   success:^(NSArray *photos, NSArray *createdPhoneNumbers) {
     if (createdPhoneNumbers.count > 0) {
       [self sendTextToPhoneNumbers:createdPhoneNumbers forPhoto:photo];
     }
   } failure:^(NSError *error) {
     DDLogError(@"%@ send failed: %@", self.class, error);
   }];
  
  [SVProgressHUD showSuccessWithStatus:@"Sent!"];
  [self gotoNextController];
}

- (void)sendTextToPhoneNumbers:(NSArray *)phoneNumbers forPhoto:(DFPeanutFeedObject *)photo
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc] initWithRecipients:phoneNumbers locationString:nil date:photo.time_taken];
    if (smsvc && [DFSMSInviteStrandComposeViewController canSendText]) {
      // Some of the invitees aren't Strand users, send them a text
      smsvc.messageComposeDelegate = self;
      [self presentViewController:smsvc
                         animated:YES
                       completion:^{
                         [SVProgressHUD dismiss];
                       }];
    }
  });
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:nil];
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

#pragma mark - DFCreateStrandFlowController delegate

- (void)createStrandFlowController:(DFCreateStrandFlowViewController *)controller
               completedWithResult:(DFCreateStrandResult)result
                            photos:(NSArray *)photos
                          contacts:(NSArray *)contacts
{
  if (result == DFCreateStrandResultSuccess) {
    [self gotoNextController];
  }
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}


@end
