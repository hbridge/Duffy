//
//  DFCreateStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandViewController.h"
#import "DFSelectPhotosController.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "NSString+DFHelpers.h"
#import "SVProgressHUD.h"
#import "DFStrandConstants.h"
#import "DFPhotoStore.h"
#import "DFPushNotificationsManager.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"

@interface DFCreateStrandViewController()

@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (nonatomic, retain) NSArray *selectedContacts;
@property (nonatomic, retain) DFPeoplePickerViewController *peoplePicker;
@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;

@end

@implementation DFCreateStrandViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;


NSUInteger const NumPhotosPerRow = 2;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions
{
  self = [super init];
  if (self) {
    _suggestionsObject = suggestions;
    [self configureNavBar];
  }
  
  return self;
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureCollectionView];
  [self configurePeoplePicker];
  [self configureSwapButtonTitle];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGFloat usableWidth = self.collectionView.frame.size.width -
  ((CGFloat)(NumPhotosPerRow - 1)  * self.flowLayout.minimumInteritemSpacing);
  CGFloat itemSize = usableWidth / (CGFloat)NumPhotosPerRow;
  self.flowLayout.itemSize = CGSizeMake(itemSize, itemSize);
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Invite to Swap";
}


- (void)configurePeoplePicker
{
  // configure the token field
  self.tokenField = [[VENTokenField alloc] initWithFrame:self.searchBarWrapperView.bounds];
  self.tokenField.maxHeight = self.searchBarWrapperView.bounds.size.height;
  
  NSArray *actors = nil;
  if (self.suggestionsObject && self.suggestionsObject.actors.count > 0) {
    actors = self.suggestionsObject.actors;
  }
  
  self.peoplePicker = [[DFPeoplePickerViewController alloc]
                       initWithTokenField:self.tokenField
                       withPeanutUsers:actors
                       tableView:self.tableView];
  self.peoplePicker.allowsMultipleSelection = YES;
  self.peoplePicker.delegate = self;
  [self.searchBarWrapperView addSubview:self.tokenField];
}

- (void)configureCollectionView
{
  self.selectPhotosController = [[DFSelectPhotosController alloc]
                                 initWithFeedPhotos:self.suggestionsObject.objects
                                 collectionView:self.collectionView
                                 sourceMode:DFImageDataSourceModeLocal
                                 imageType:DFImageThumbnail];
  self.selectPhotosController.delegate = self;
  self.collectionView.alwaysBounceVertical = YES;
  self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, self.swapBarWrapper.frame.size.height, 0);
}

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  [self configureSwapButtonTitle];
}

- (void)configureSwapButtonTitle
{
  NSUInteger selectedCount = self.selectPhotosController.selectedPhotoIDs.count;
  if (selectedCount > 0) {
    NSString *title = [NSString stringWithFormat:@"Swap %d Photos",
                       (int)selectedCount];
    [self.swapPhotosButton setTitle:title forState:UIControlStateNormal];
    self.swapPhotosButton.enabled = YES;
    self.swapBarWrapper.alpha = 1.0;
  } else {
    [self.swapPhotosButton setTitle:@"No Photos Selected" forState:UIControlStateDisabled];
    self.swapPhotosButton.enabled = NO;
    self.swapBarWrapper.alpha = 0.7;
  }
  
}

#pragma mark - Actions

- (IBAction)swapPhotosButtonPressed:(UIButton *)sender {
  [self.tokenField resignFirstResponder];
  [self createNewStrandWithSelection];
}

- (void)createNewStrandWithSelection
{
  // Create the strand
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.users = @[@([[DFUser currentUser] userID])];
  requestStrand.photos = self.selectPhotosController.selectedPhotoIDs;
  requestStrand.created_from_id = [NSNumber numberWithLongLong:self.suggestionsObject.id];
  requestStrand.private = @(NO);
  [self setTimesForStrand:requestStrand fromPhotoObjects:self.suggestionsObject.enumeratorOfDescendents.allObjects];
  
  [SVProgressHUD show];
  [self.strandAdapter
   performRequest:RKRequestMethodPOST
   withPeanutStrand:requestStrand success:^(DFPeanutStrand *peanutStrand) {
     DDLogInfo(@"%@ successfully created strand: %@", self.class, peanutStrand);
     
     [[NSNotificationCenter defaultCenter]
      postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
      object:self];
     
     // invite selected users
     [self sendInvitesForStrand:peanutStrand
               toPeanutContacts:self.peoplePicker.selectedPeanutContacts
      ];
     
     // start uploading the photos
     [[DFPhotoStore sharedStore] markPhotosForUpload:peanutStrand.photos];
     [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:peanutStrand.photos];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
     DDLogError(@"%@ failed to create strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
{
  [self.inviteAdapter
   sendInvitesForStrand:peanutStrand
   toPeanutContacts:peanutContacts
   inviteLocationString:self.suggestionsObject.location
   invitedPhotosDate:self.suggestionsObject.time_taken
   success:^(DFSMSInviteStrandComposeViewController *vc) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (vc) {
         vc.messageComposeDelegate = self;
         [self presentViewController:vc
                            animated:YES
                          completion:nil];
         [SVProgressHUD dismiss];
       } else {
         [self dismissWithErrorString:nil];
       }
     });
   } failure:^(NSError *error) {
     [self dismissWithErrorString:@"Invite failed"];
     DDLogError(@"%@ failed to invite to strand: %@, error: %@",
                self.class, peanutStrand, error);
   }];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissWithErrorString:(result == MessageComposeResultSent ? nil : @"Cancelled")];
}

- (void)dismissWithErrorString:(NSString *)errorString
{
  void (^completion)(void) = ^{
    if (!errorString) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Sent!"];
      });
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
      });
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:errorString];
      });
    }
  };
  
  if (self.presentedViewController) {
    [self dismissViewControllerAnimated:YES completion:completion];
    [self.navigationController popViewControllerAnimated:NO];
  } else {
    [self.navigationController popViewControllerAnimated:YES];
    completion();
  }
}

- (void)setTimesForStrand:(DFPeanutStrand *)strand fromPhotoObjects:(NSArray *)objects
{
  NSDate *minDateFound;
  NSDate *maxDateFound;
  
  for (DFPeanutFeedObject *object in objects) {
    if (!minDateFound || [object.time_taken compare:minDateFound] == NSOrderedAscending) {
      minDateFound = object.time_taken;
    }
    if (!maxDateFound || [object.time_taken compare:maxDateFound] == NSOrderedDescending) {
      maxDateFound = object.time_taken;
    }
  }
  
  strand.first_photo_time = minDateFound;
  strand.last_photo_time = maxDateFound;
}



#pragma mark - DFPeoplePicker delegate

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didPickContacts:(NSArray *)peanutContacts
{
  self.selectedContacts = peanutContacts;
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
           textDidChange:(NSString *)text
{
  self.tableView.hidden = ![text isNotEmpty];
}

- (IBAction)collectionViewTapped:(id)sender {
  [self.tokenField resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  [self.tokenField resignFirstResponder];
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  return _strandAdapter;
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}



@end
