//
//  DFSuggestionsPageViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionsPageViewController.h"
#import "DFSuggestionViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFNavigationController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface DFSuggestionsPageViewController ()

@property (nonatomic, retain) NSArray *allSuggestions;
@property (nonatomic, retain) NSMutableArray *filteredSuggestions;
@property (nonatomic, retain) DFPeanutFeedObject *pickedSuggestion;
@property (nonatomic, retain) DFPeanutStrand *lastCreatedStrand;
@property (nonatomic, retain) NSMutableArray *suggestionsToRemove;

@end

@implementation DFSuggestionsPageViewController


- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                options:nil];
  if (self) {
    self.delegate = self;
    self.dataSource = self;
    [self observeNotifications];
    [self configureNavAndTab];
    self.suggestionsToRemove = [NSMutableArray new];
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
  self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadData
{
  self.allSuggestions = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
  self.filteredSuggestions = [self.allSuggestions mutableCopy];
  if (self.userToFilter) {
    NSMutableArray *filteredSuggestions = [NSMutableArray new];
    for (DFPeanutFeedObject *suggestion in self.allSuggestions) {
      if ([suggestion.actors containsObject:self.userToFilter]) {
        [filteredSuggestions addObject:suggestion];
      }
    }
  }
  
  [self.filteredSuggestions removeObjectsInArray:self.suggestionsToRemove];
  
  if (self.viewControllers.count == 0 && self.filteredSuggestions.count > 0) {
    DFSuggestionViewController *svc = [self viewControllerForIndex:0];
    [self setViewControllers:@[svc]
                   direction:UIPageViewControllerNavigationDirectionForward
                    animated:NO
                  completion:nil];
  }
}

- (NSUInteger)indexOfViewController:(UIViewController *)viewController
{
  DFSuggestionViewController *suggestionVC = (DFSuggestionViewController *)viewController;
  NSInteger currentIndex = [self.filteredSuggestions indexOfObject:suggestionVC.suggestionFeedObject];
  return currentIndex;
}


- (NSUInteger)currentViewControllerIndex
{
  UIViewController *currentController = self.viewControllers.firstObject;
  return  [self indexOfViewController:currentController];
}


- (DFSuggestionViewController *)viewControllerForIndex:(NSInteger)index
{
  DFPeanutFeedObject *suggestion = self.filteredSuggestions[index];
  DFSuggestionViewController *svc = [[DFSuggestionViewController alloc] init];
  svc.suggestionFeedObject = suggestion;
  svc.frame = self.view.bounds;
  DFSuggestionsPageViewController __weak *weakSelf = self;
  svc.requestButtonHandler = ^{
    [weakSelf suggestionSelected:suggestion];
  };
  return svc;
}


#pragma mark - UIPageViewController Delegate/Datasource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.filteredSuggestions.count < 2) return nil;
  
  NSUInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) beforeIndex = self.filteredSuggestions.count - 1; // wrap around
  return [self viewControllerForIndex:beforeIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.filteredSuggestions.count < 2) return nil;
  NSInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.filteredSuggestions.count) afterIndex = 0; // wrap around
  return [self viewControllerForIndex:afterIndex];
}

- (void)suggestionSelected:(DFPeanutFeedObject *)suggestion
{
  self.pickedSuggestion = suggestion;
  DFPeoplePickerViewController *peoplePicker = [[DFPeoplePickerViewController alloc]
                                                initWithSuggestedPeanutUsers:suggestion.actors];
  peoplePicker.allowsMultipleSelection = YES;
  peoplePicker.delegate = self;
  peoplePicker.navigationItem.title = @"Who was there?";
  
  [DFNavigationController presentWithRootController:peoplePicker inParent:self];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  [[DFPeanutFeedDataManager sharedManager]
   createRequestFromSuggestion:self.pickedSuggestion
   contacts:peanutContacts
   success:^(DFPeanutStrand *resultStrand) {
     DDLogInfo(@"%@ created empty strand", self.class);
     //self.suggestionToUpsellAdd = suggestion
     
     UIViewController *nextController = [self pageViewController:self viewControllerAfterViewController:self.viewControllers.firstObject];
     [self setViewControllers:@[nextController]
                    direction:UIPageViewControllerNavigationDirectionForward
                     animated:NO
                   completion:nil];
     [self.suggestionsToRemove addObject:self.pickedSuggestion];
     [self.filteredSuggestions removeObject:self.pickedSuggestion];
     self.lastCreatedStrand = resultStrand;
     
     
     
     DFPeanutStrandInviteAdapter *adapter = [[DFPeanutStrandInviteAdapter alloc] init];
     [adapter
      sendInvitesForStrand:resultStrand
      toPeanutContacts:peanutContacts
      inviteLocationString:self.pickedSuggestion.location
      invitedPhotosDate:resultStrand.first_photo_time
      success:^(DFSMSInviteStrandComposeViewController *composeView) {
        DDLogInfo(@"%@ created empty strand and invite successful", self.class);
        [SVProgressHUD showSuccessWithStatus:@"Request Sent"];
      } failure:^(NSError *error) {
        DDLogError(@"%@ invite failed: %@", self.class, error);
      }];
     [self dismissViewControllerAnimated:YES completion:nil];
   } failure:^(NSError *error) {
     DDLogError(@"%@ creating empty strand failed: %@", self.class, error);
   }];
}


@end
