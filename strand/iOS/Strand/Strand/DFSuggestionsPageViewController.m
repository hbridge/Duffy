//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionsPageViewController.h"
#import "DFSwipableSuggestionViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNavigationController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFNoTableItemsView.h"
#import "DFUploadController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFDefaultsStore.h"

@interface DFSuggestionsPageViewController ()

@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) NSMutableArray *suggestionsToRemove;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic, readonly, retain) DFPeanutStrandInviteAdapter *inviteAdapter;

@property (nonatomic) NSInteger photoIndex;
@property (retain, nonatomic) NSMutableArray *indexPaths;

@end

@implementation DFSuggestionsPageViewController
@synthesize inviteAdapter = _inviteAdapter;


- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
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
  self.allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  self.filteredSuggestions = [self.allSuggestions mutableCopy];
  
  NSInteger sectionCount = 0;
  self.indexPaths = [NSMutableArray new];
  
  NSMutableArray *filteredSuggestions = [NSMutableArray new];
  for (DFPeanutFeedObject *suggestion in self.allSuggestions) {
    if (!self.userToFilter || (self.userToFilter && [suggestion.actors containsObject:self.userToFilter])) {
      NSInteger itemCount = 0;
      [filteredSuggestions addObject:suggestion];
      NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
      for (int x=0; x < photos.count; x++) {
        [self.indexPaths addObject:[NSIndexPath indexPathForItem:itemCount inSection:sectionCount]];
        itemCount++;
      }
      sectionCount++;
    }
  }
  
  if (![DFDefaultsStore isSetupStepPassed:DFSetupStepSuggestionsNux]) {
    // go in reverse order to make sure path 0 is at index 0
    [self.indexPaths insertObject:[NSIndexPath indexPathForItem:1 inSection:NSIntegerMin] atIndex:0];
    [self.indexPaths insertObject:[NSIndexPath indexPathForItem:0 inSection:NSIntegerMin] atIndex:0];
  }
  
  if ((self.viewControllers.count == 0
      || ![[self.viewControllers.firstObject class] // if the VC isn't a suggestion, reload in case there is one now
           isSubclassOfClass:[DFSuggestionViewController class]])
      && [[DFPeanutFeedDataManager sharedManager] areSuggestionsReady])
    [self gotoNextController];
  [self configureLoadingView];
}

- (void)configureLoadingView
{
  if (self.filteredSuggestions.count == 0) {
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
  if (![[viewController class] isSubclassOfClass:[DFSuggestionViewController class]]) return -1;
  DFSuggestionViewController *suggestionVC = (DFSuggestionViewController *)viewController;
  if (suggestionVC.nuxStep > 0) {
    return suggestionVC.nuxStep - 1;
  }
  NSUInteger sectionIndex = [self.filteredSuggestions indexOfObject:suggestionVC.suggestionFeedObject];
  
  if (sectionIndex == NSNotFound) return -1;
  NSArray *photos = [self.filteredSuggestions[sectionIndex] leafNodesFromObjectOfType:DFFeedObjectPhoto];
  NSUInteger itemIndex = [photos indexOfObject:suggestionVC.photoFeedObject];
  if (itemIndex == NSNotFound) return -1;
  
  for (int x=0; x < self.indexPaths.count; x++) {
    NSIndexPath *indexPath = self.indexPaths[x];
    if (indexPath.section == sectionIndex && indexPath.item == itemIndex) {
      return x;
    }
  }
  return -1;
}


- (NSUInteger)currentViewControllerIndex
{
  UIViewController *currentController = self.viewControllers.firstObject;
  return  [self indexOfViewController:currentController];
}

- (DFSuggestionViewController *)viewControllerForIndex:(NSInteger)index
{
  if (index < 0 || index >= self.filteredSuggestions.count) {
    if (self.filteredSuggestions.count > 0) {
      DDLogWarn(@"%@ viewControllerForIndex: %@ filteredSuggestions.count: %@",
                self.class,
                @(index),
                @(self.filteredSuggestions.count));
      return nil;
    }
  }
  NSIndexPath *indexPath = self.indexPaths[index];
  
  if (indexPath.section == NSIntegerMin) {
    // this is a nux request
    return [self suggestionViewControllerForNuxStep:indexPath.row + 1];
  }
  
  DFPeanutFeedObject *suggestion = self.filteredSuggestions[indexPath.section];
  NSArray *photos = [suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto];
  DFPeanutFeedObject *photo = photos[indexPath.item];
  
  
  DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc] init];
  svc.suggestionFeedObject = suggestion;
  svc.photoFeedObject = photo;

  svc.frame = self.view.bounds;
  DFSuggestionsPageViewController __weak *weakSelf = self;
  
  svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
    [weakSelf suggestionSelected:suggestion contacts:contacts photo:photo];
  };
  svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
    [weakSelf suggestionHidden:suggestion photo:photo];
  };
  
  return svc;
}
        
- (DFSuggestionViewController *)suggestionViewControllerForNuxStep:(NSUInteger)nuxStep
{
  DFSwipableSuggestionViewController *svc = [[DFSwipableSuggestionViewController alloc]
                                             initWithNuxStep:nuxStep];
  if (nuxStep == 1) {
    svc.yesButtonHandler = ^(DFPeanutFeedObject *suggestion, NSArray *contacts){
      [SVProgressHUD showSuccessWithStatus:@"Nice!"];
      [self gotoNextController];
    };
  } else if (nuxStep == 2) {
     svc.noButtonHandler = ^(DFPeanutFeedObject *suggestion){
       [SVProgressHUD showSuccessWithStatus:@"On to your photos!"];
       [self gotoNextController];
       [DFDefaultsStore setSetupStepPassed:DFSetupStepSuggestionsNux Passed:YES];
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
  if (self.filteredSuggestions.count < 2) return nil;
  
  NSUInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) return nil;
  return [self viewControllerForIndex:beforeIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.filteredSuggestions.count < 2) return nil;
  NSInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.filteredSuggestions.count) return nil;
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

- (void)suggestionHidden:(DFPeanutFeedObject *)suggestion  photo:(DFPeanutFeedObject *)photo
{
  if (photo)
    [[DFPeanutFeedDataManager sharedManager] hasEvaluatedPhoto:photo.id strandID:suggestion.id];
  [self gotoNextController];
}

- (void)gotoNextController
{
  UIViewController *nextController;
  if (self.filteredSuggestions.count > 0) {
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
