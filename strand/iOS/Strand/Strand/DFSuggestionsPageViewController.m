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
#import "DFCommentViewController.h"
#import "DFImageManagerRequest.h"
#import "DFImageDiskCache.h"

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
@property (nonatomic) NSUInteger highestSeenNuxStep;

@end

const NSUInteger NumNuxes = 3;

@implementation DFSuggestionsPageViewController
@synthesize inviteAdapter = _inviteAdapter;
@synthesize noSuggestionsViewController = _noSuggestionsViewController;

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType
{
  self = [self init];
  if (self) {
    _preferredType = preferredType;
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
  self.view.backgroundColor = [UIColor whiteColor];
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
  
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]
      && self.highestSeenNuxStep < NumNuxes) {
    nextController = [self viewControllerForNuxStep:self.highestSeenNuxStep];
  } else {
    if (self.preferredType == DFIncomingViewType) {
      nextController = [self nextIncomingViewController];
    } else {
      nextController = [self nextSuggestionViewController];
    }
  }
  
  if (!nextController) {
    nextController = [self noSuggestionsViewController];
  } 
  
  [self setViewControllers:@[nextController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:YES
                completion:nil];
}

- (UIViewController *)nextIncomingViewController
{
  NSArray *friends = [[DFPeanutFeedDataManager sharedManager] friendsList];
  // First, lets go through your shared strands with friends and see if theres any photos you haven't looked at yet
  for (DFPeanutUserObject *user in friends) {
    NSArray *strands = [[DFPeanutFeedDataManager sharedManager] publicStrandsWithUser:user includeInvites:NO];
    for (DFPeanutFeedObject *strandPosts in strands) {
      NSArray *photos = [[DFPeanutFeedDataManager sharedManager] nonEvaluatedPhotosInStrandPosts:strandPosts];
      for (DFPeanutFeedObject *photo in photos) {
        if (photo.user != [[DFUser currentUser] userID] &&
            ![self.alreadyShownPhotoIds containsObject:@(photo.id)]) {
          
          // Now lets see if the image is loaded yet
          DFImageManagerRequest *request = [[DFImageManagerRequest alloc] initWithPhotoID:photo.id imageType:DFImageFull];
          if ([[DFImageDiskCache sharedStore] canServeRequest:request]) {
            DFIncomingViewController *ivc = [[DFIncomingViewController alloc] initWithPhotoID:photo.id inStrand:strandPosts.id fromSender:user];
            [self.alreadyShownPhotoIds addObject:@(photo.id)];
            
            DFSuggestionsPageViewController __weak *weakSelf = self;
            ivc.nextHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
              [weakSelf photoSkipped:photoID strand:strandID];
            };
            ivc.commentHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
              [weakSelf showCommentsForPhoto:photoID strand:strandID];
            };
            ivc.likeHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
              [weakSelf likePhoto:photoID strand:strandID];
            };

            return ivc;
          }
        }
      }
    }
  }
  return nil;
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
          svc.frame = self.view.bounds;
          [svc configureWithSuggestion:suggestion withPhoto:photo];
          DFSuggestionsPageViewController __weak *weakSelf = self;

          svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
            [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo];
          };
          svc.noButtonHandler = ^(DFPeanutFeedObject *strand){
            [weakSelf photoSkipped:photo.id strand:strand.id];
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
    if (!self.noResultsView) self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
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
  if (index == 0) {
    DFIncomingViewController *ivc = [[DFIncomingViewController alloc] initWithNuxStep:1];
    nuxController = ivc;
    ivc.nextHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
      [SVProgressHUD showSuccessWithStatus:@"Aw, man!"];
      [self gotoNextController];
    };
    ivc.commentHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
      [SVProgressHUD showErrorWithStatus:@"Let's keep things simple..."];
    };
    ivc.likeHandler = ^(DFPhotoIDType photoID, DFStrandIDType strandID){
      [SVProgressHUD showSuccessWithStatus:@"Sweet!"];
      [self gotoNextController];
    };

  } else {
    DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc]
                                               initWithNuxStep:index];
    nuxController = svc;
    svc.index = index;
    svc.nuxStep = index;
    
    if (index == 1) {
      svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
        [SVProgressHUD showSuccessWithStatus:@"Nice!"];
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
    if (self.preferredType == DFSuggestionViewType) {
      noSuggestionsView.titleLabel.text = @"No More Suggestions";
      noSuggestionsView.subtitleLabel.text = @"Take more photos or invite more friends.";
    } else {
      noSuggestionsView.titleLabel.text = @"No More to Review";
      noSuggestionsView.subtitleLabel.text = @"Send some photos to friends";
    }
    noSuggestionsView.superView = _noSuggestionsViewController.view;
  }
  return _noSuggestionsViewController;
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
  // figure out which selected contacts are users
  NSMutableArray *users = [NSMutableArray new];
  for (DFPeanutContact *contact in contacts) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager]
                                getUserWithPhoneNumber:contact.phone_number];
    if (user) [users addObject:user];
  }
  
  // if any are users share photos with them
  if (users.count > 0) {
    [[DFPeanutFeedDataManager sharedManager] sharePhotoWithFriends:photo users:suggestion.actors];
  }
  
  // if there are more contacts, create a strand for each and send invites
  if (contacts.count > users.count) {
    [self createStrandsForPhoto:photo sendInvitesToContacts:contacts fromSuggestion:suggestion];
  }
  
  [SVProgressHUD showSuccessWithStatus:@"Sent!"];
  [self gotoNextController];
}

- (void)createStrandsForPhoto:(DFPeanutFeedObject *)photo
        sendInvitesToContacts:(NSArray *)contacts
               fromSuggestion:(DFPeanutFeedObject *)suggestion
{
  DFSuggestionsPageViewController __weak *weakSelf = self;
  [SVProgressHUD show];
  for (DFPeanutContact *contact in contacts) {
    [[DFPeanutFeedDataManager sharedManager]
     createNewStrandWithFeedObjects:@[photo]
     additionalUserIds:nil
     success:^(DFPeanutStrand *createdStrand){
       [weakSelf sendInvitesForStrand:createdStrand
                     toPeanutContacts:@[contact]
                           suggestion:suggestion];
     } failure:^(NSError *error) {
       [SVProgressHUD showErrorWithStatus:error.localizedDescription];
       DDLogError(@"%@ create failed: %@", weakSelf.class, error);
     }];
  }
}

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
                  suggestion:(DFPeanutFeedObject *)suggestion
{
  DFSuggestionsPageViewController __weak *weakSelf = self;
  [self.inviteAdapter
   sendInvitesForStrand:peanutStrand
   toPeanutContacts:peanutContacts
   inviteLocationString:suggestion.location
   invitedPhotosDate:suggestion.time_taken
   success:^(DFSMSInviteStrandComposeViewController *vc) {
     dispatch_async(dispatch_get_main_queue(), ^{
       DDLogInfo(@"Created strand successfully");
       if (vc && [DFSMSInviteStrandComposeViewController canSendText]) {
         // Some of the invitees aren't Strand users, send them a text
         vc.messageComposeDelegate = weakSelf;
         [weakSelf presentViewController:vc
                                animated:YES
                              completion:^{
                                [SVProgressHUD dismiss];
                              }];
       } else {
         [SVProgressHUD dismiss];
       }
     });
   } failure:^(NSError *error) {
     DDLogError(@"%@ failed to invite to strand: %@, error: %@",
                weakSelf.class, peanutStrand, error);
   }];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)photoSkipped:(DFPhotoIDType)photoID strand:(DFStrandIDType)strandID
{
  if (photoID)
    [[DFPeanutFeedDataManager sharedManager] hasEvaluatedPhoto:photoID strandID:strandID];
  [self gotoNextController];
}

- (void)showCommentsForPhoto:(DFPhotoIDType)photo strand:(DFStrandIDType)strand
{
  DFPeanutFeedObject *strandPosts = [[DFPeanutFeedDataManager sharedManager] strandPostsObjectWithId:strand];
  DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager] photoWithID:photo inStrand:strand];
  DFCommentViewController *cvc = [[DFCommentViewController alloc]
                                  initWithPhotoObject:photoObject
                                  inPostsObject:strandPosts];
  [DFNavigationController presentWithRootController:cvc
                                           inParent:self
                                withBackButtonTitle:@"Close"];
  
}

- (void)likePhoto:(DFPhotoIDType)photo strand:(DFStrandIDType)strand
{
  [[DFPeanutFeedDataManager sharedManager]
   setLikedByUser:YES
   photo:photo
   inStrand:strand
   oldActionID:0
   success:^(DFActionID actionID) {
    
  } failure:^(NSError *error) {
    
  }];
  [[DFPeanutFeedDataManager sharedManager] hasEvaluatedPhoto:photo strandID:strand];
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
