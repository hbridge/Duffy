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
@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;

@end

@implementation DFCreateStrandViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;


NSUInteger const NumPhotosPerRow = 4;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions
{
  self = [super init];
  if (self) {
    _suggestionsObject = suggestions;
    [self configureNavBar];
  }
  
  return self;
}

- (IBAction)selectAllButtonPressed:(UIButton *)sender {
  // if everything's selected, deselect all
  NSString *newTitle;
  BOOL showTickMark;

  if (self.selectPhotosController.selectedFeedObjects.count == self.suggestionsObject.objects.count) {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Select All";
    showTickMark = NO;
  } else {
    [self.selectPhotosController.selectedFeedObjects removeAllObjects];
    newTitle = @"Deselect All";
    showTickMark = YES;
    [self.selectPhotosController.selectedFeedObjects addObjectsFromArray:self.suggestionsObject.objects];
  }
  
  for (DFSelectablePhotoViewCell *cell in self.collectionView.visibleCells) {
    cell.showTickMark = showTickMark;
    [cell setNeedsLayout];
  }
  [self.selectAllButton setTitle:newTitle forState:UIControlStateNormal];
  [self configureNavTitle];
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureHeader];
  [self configureCollectionView];
  [self configureNavTitle];
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
  self.navigationItem.title = @"Select Photos";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithTitle:@"Next"
                                            style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(nextPressed:)];
}

- (void)configureHeader
{
  self.locationLabel.text = self.suggestionsObject.location;
  self.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:self.suggestionsObject.time_taken
                                                          abbreviate:NO];
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
}

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
    selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  [self configureNavTitle];
}

- (void)configureNavTitle
{
  NSUInteger selectedPhotosCount = self.selectPhotosController.selectedPhotoIDs.count;
  
  // set the title based on photos selected
  if (selectedPhotosCount == 0) {
    self.navigationItem.title = @"No Photos Selected";
    self.navigationItem.rightBarButtonItem.enabled = NO;
  } else {
    NSString *title = [NSString stringWithFormat:@"%d Photos Selected",
                       (int)selectedPhotosCount];
    self.navigationItem.title = title;
    self.navigationItem.rightBarButtonItem.enabled = YES;
  }
}

#pragma mark - Actions

- (void)nextPressed:(id)sender {
  DFPeoplePickerViewController *peoplePicker =[[DFPeoplePickerViewController alloc] init];
  peoplePicker.delegate = self;
  peoplePicker.allowsMultipleSelection = YES;
  [self.navigationController pushViewController:peoplePicker animated:YES];
}

- (void)createNewStrandWithSelectedPhotoIDs:(NSArray *)selectedPhotoIDs
                     selectedPeanutContacts:(NSArray *)selectedPeanutContacts
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
               toPeanutContacts:selectedPeanutContacts
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
       // Some of the invitees aren't Strand users, send them a text
       if (vc && [DFSMSInviteStrandComposeViewController canSendText]) {
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
  [self dismissWithErrorString:(result == MessageComposeResultSent ? nil : @"Some invites not sent")];
}

- (void)dismissWithErrorString:(NSString *)errorString
{
  void (^completion)(void) = ^{
    if (!errorString) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Sent!"];
      });
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
      });
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:errorString];
      });
    }
  };
  
  if (self.presentingViewController) {
    // the create flow was presented as a sheet, dismiss the whole thing
    [self.presentingViewController dismissViewControllerAnimated:YES completion:completion];
  } else {
    if (self.presentedViewController) {
      [self dismissViewControllerAnimated:YES completion:completion];
      [self.navigationController popViewControllerAnimated:NO];
    } else {
      [self.navigationController popViewControllerAnimated:YES];
      completion();
    }
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
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  // create strand
  [self createNewStrandWithSelectedPhotoIDs:self.selectPhotosController.selectedPhotoIDs
                     selectedPeanutContacts:peanutContacts];
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
