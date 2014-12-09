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

@interface DFSuggestionsPageViewController ()

@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) NSMutableArray *suggestionsToRemove;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic, readonly, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (nonatomic, retain) NSArray *lastSentContacts;

@property (nonatomic) NSInteger photoIndex;
@property (retain, nonatomic) NSMutableArray *indexPaths;

@property (retain, nonatomic) NSMutableArray *photoList;
@property (retain, nonatomic) NSMutableArray *strandList;
@property (retain, nonatomic) NSMutableArray *subViewTypeList;

@end

@implementation DFSuggestionsPageViewController
@synthesize inviteAdapter = _inviteAdapter;


- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationVertical
                                options:nil];
  if (self) {
    self.delegate = self;
    [self observeNotifications];
    [self configureNavAndTab];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewSwapsDataNotificationName
                                             object:nil];
}

- (void)configureNavAndTab
{
  self.navigationItem.title = @"Suggestions";
  self.tabBarItem.title = @"Suggestions";
  self.tabBarItem.image = [UIImage imageNamed:@"Assets/Icons/SwapBarButton"];
  self.tabBarItem.selectedImage = [UIImage imageNamed:@"Assets/Icons/SwapBarButtonSelected"];
//  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
//                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
//                                            target:self
//                                            action:@selector(createButtonPressed:)];
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
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[DFPeanutFeedDataManager sharedManager] refreshSwapsFromServer:nil];
  [self configureLoadingView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadData
{
  
  self.photoList = [NSMutableArray new];
  self.strandList = [NSMutableArray new];
  self.subViewTypeList = [NSMutableArray new];
  
  
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    // Add two entries for NUX
    [self.photoList addObject:@(0)];
    [self.strandList addObject:@(0)];
    [self.subViewTypeList addObject:@(DFNuxViewType)];
    
    [self.photoList addObject:@(0)];
    [self.strandList addObject:@(0)];
    [self.subViewTypeList addObject:@(DFNuxViewType)];
  }
  
  NSArray *friends = [[DFPeanutFeedDataManager sharedManager] friendsList];
  
  for (DFPeanutUserObject *user in friends) {
    NSArray *strands = [[DFPeanutFeedDataManager sharedManager] publicStrandsWithUser:user includeInvites:NO];
    for (DFPeanutFeedObject *strandPosts in strands) {
      NSArray *photos = [[DFPeanutFeedDataManager sharedManager] nonEvaluatedPhotosInStrandPosts:strandPosts];
      for (DFPeanutFeedObject *photo in photos) {
        if (photo.user != [[DFUser currentUser] userID]) {
          [self.photoList addObject:photo];
          [self.strandList addObject:strandPosts];
          [self.subViewTypeList addObject:@(DFIncomingViewType)];
        }
      }
    }
  }
 
  NSArray *allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  for (DFPeanutFeedObject *suggestion in allSuggestions) {
    if (!self.userToFilter || (self.userToFilter && [suggestion.actors containsObject:self.userToFilter])) {
      
      NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
      for (int x=0; x < photos.count; x++) {
        [self.photoList addObject:photos[x]];
        [self.strandList addObject:suggestion];
        [self.subViewTypeList addObject:@(DFSuggestionViewType)];
      }
    }
  }
  
  
  /*
   TODO(Derek): put NUX back in, here is what it was before
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    // go in reverse order to make sure path 0 is at index 0
    [self.indexPaths insertObject:[NSIndexPath indexPathForItem:1 inSection:NSIntegerMin] atIndex:0];
    [self.indexPaths insertObject:[NSIndexPath indexPathForItem:0 inSection:NSIntegerMin] atIndex:0];
  }*/
  
  if ((self.viewControllers.count == 0
      || ![[self.viewControllers.firstObject class] // if the VC isn't a suggestion, reload in case there is one now
           isSubclassOfClass:[DFSuggestionViewController class]])
      && [[DFPeanutFeedDataManager sharedManager] areSuggestionsReady])
    [self gotoNextController];
  [self configureLoadingView];
}

- (void)configureLoadingView
{
  if (self.photoList.count == 0) {
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
  /*
  if (suggestionVC.nuxStep > 0) {
    return suggestionVC.nuxStep - 1;
  }
   TODO(Derek): put NUX back in, here is what it was before
  NSUInteger sectionIndex = [self.filteredSuggestions indexOfObject:suggestionVC.suggestionFeedObject];

   */
}


- (NSUInteger)currentViewControllerIndex
{
  UIViewController *currentController = self.viewControllers.firstObject;
  return  [self indexOfViewController:currentController];
}

- (DFHomeSubViewController *)viewControllerForIndex:(NSInteger)index
{
  if (index < 0 || index >= self.photoList.count) {
    if (self.photoList.count > 0) {
      DDLogWarn(@"%@ viewControllerForIndex: %@ photoList: %@",
                self.class,
                @(index),
                @(self.photoList.count));
      return nil;
    }
  }
  
  DFSuggestionsPageViewController __weak *weakSelf = self;
  
  DFPeanutFeedObject *strand = self.strandList[index];
  DFPeanutFeedObject *photo = self.photoList[index];
  
  if ([self.subViewTypeList[index] isEqualToValue:@(DFSuggestionViewType)]) {
    DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc] init];
    if (strand.actors.count == 0) svc.selectedPeanutContacts = self.lastSentContacts;
    svc.suggestionFeedObject = strand;
    svc.photoFeedObject = photo;
    svc.index = index;
    
    svc.frame = self.view.bounds;
    
    
    svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
      [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo];
    };
    svc.noButtonHandler = ^(DFPeanutFeedObject *strand){
      [weakSelf photoSkipped:photo.id strand:strand.id];
    };
    return svc;
  } else if ([self.subViewTypeList[index] isEqualToValue:@(DFIncomingViewType)]) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:photo.user];
    DFIncomingViewController *ivc = [[DFIncomingViewController alloc] initWithPhotoID:photo.id inStrand:strand.id fromSender:user];
    ivc.index = index;
    
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
  } else if ([self.subViewTypeList[index] isEqualToValue:@(DFNuxViewType)]) {
    // this is a nux request
    return [self suggestionViewControllerForNuxStep:index];
  }
  return nil;
}
        
- (DFSuggestionViewController *)suggestionViewControllerForNuxStep:(NSUInteger)index
{
  DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc]
                                             initWithNuxStep:index];
  svc.index = index;
  svc.nuxStep = index + 1;
  if (index == 0) {
    svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
      [SVProgressHUD showSuccessWithStatus:@"Nice!"];
      [self gotoNextController];
    };
    svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion) {
      [SVProgressHUD showErrorWithStatus:@"Tap Send to continue"];
    };
  } else if (index == 1) {
     svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
       [SVProgressHUD showSuccessWithStatus:@"On to your photos!"];
       [self gotoNextController];
       [DFDefaultsStore setSetupStepPassed:DFSetupStepSuggestionsNux Passed:YES];
     };
    svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
      [SVProgressHUD showErrorWithStatus:@"Tap Skip to continue"];
    };
  }
  
  return svc;
}

- (UIViewController *)noSuggestionsViewController
{
  UIViewController *noSuggestionVC = [[UIViewController alloc] init];
  DFNoTableItemsView *noSuggestionsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
  noSuggestionsView.titleLabel.text = @"No More Suggestions";
  noSuggestionsView.subtitleLabel.text = @"Take more photos or invite more friends.";
  noSuggestionsView.superView = noSuggestionVC.view;
  return noSuggestionVC;
}


#pragma mark - UIPageViewController Delegate/Datasource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.photoList.count < 2) return nil;
  
  NSUInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) return nil;
  return [self viewControllerForIndex:beforeIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.photoList.count < 2) return nil;
  NSInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.photoList.count) return nil;
  return [self viewControllerForIndex:afterIndex];
}

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
                                           inParent:self];
  dispatch_async(dispatch_get_main_queue(), ^{
    cvc.navigationItem.leftBarButtonItem.title = @"Back";
  });
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

- (void)gotoNextController
{
  UIViewController *nextController;
  if (self.photoList.count > 0) {
    if (self.viewControllers.count == 0) {
      nextController = [self viewControllerForIndex:0];
    } else {
      UIViewController *currentController = self.viewControllers.firstObject;
      nextController = [self pageViewController:self
              viewControllerAfterViewController:currentController];
    }
  }
  
  if (!nextController)
    nextController = [self noSuggestionsViewController];

  [self setViewControllers:@[nextController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:YES
                completion:nil];

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
