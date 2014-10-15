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
#import "NSArray+DFHelpers.h"

@interface DFCreateStrandViewController()

@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (nonatomic, retain) NSArray *selectedContacts;
@property (nonatomic, retain) DFPeanutFeedObject *suggestedSection;

@end

@implementation DFCreateStrandViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;


NSUInteger const NumPhotosPerRow = 4;

- (instancetype)initWithSuggestions:(NSArray *)suggestions
{
  self = [super initWithSuggestions:suggestions];
  if (self) {
    _suggestedSection = [suggestions firstObject];
    [self configureNavBar];
  }
  return self;
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
}

- (void)setSuggestedSections:(NSArray *)suggestedSections
{
  [super setSuggestedSections:suggestedSections];
  self.suggestedSection = suggestedSections.firstObject;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.swapButton setTitle:@"Next" forState:UIControlStateNormal];
  [self.swapButton addTarget:self action:@selector(nextPressed:)
            forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Actions


- (void)nextPressed:(id)sender {
  NSArray *peanutContacts = [self.suggestedSection.actors arrayByMappingObjectsWithBlock:^id(DFPeanutUserObject *user) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:user];
    return contact;
  }];
  DFPeoplePickerViewController *peoplePicker =[[DFPeoplePickerViewController alloc]
                                               initWithSuggestedPeanutContacts:peanutContacts];
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
  requestStrand.created_from_id = [NSNumber numberWithLongLong:self.suggestedSection.id];
  requestStrand.private = @(NO);
  [self setTimesForStrand:requestStrand fromPhotoObjects:self.suggestedSection.enumeratorOfDescendents.allObjects];
  
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
   inviteLocationString:self.suggestedSection.location
   invitedPhotosDate:self.suggestedSection.time_taken
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
