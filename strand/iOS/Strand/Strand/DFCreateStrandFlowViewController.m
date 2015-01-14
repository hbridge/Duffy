//
//  DFCreateStrandFlowViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandFlowViewController.h"
#import "DFPeanutFeedDataManager.h"

#import "SVProgressHUD.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFAnalytics.h"

@interface DFCreateStrandFlowViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;

@end


@implementation DFCreateStrandFlowViewController

@synthesize inviteAdapter = _inviteAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
  }
  return self;
}

- (instancetype)initWithHighlightedPhotoCollection:(DFPeanutFeedObject *)highlightedCollection
{
  self = [self init];
  if (self) {
    _highlightedCollection = highlightedCollection;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.selectPhotosController = [[DFSelectPhotosViewController alloc] init];
  self.selectPhotosController.highlightedFeedObject = self.highlightedCollection;
  self.selectPhotosController.delegate = self;
  [self pushViewController:self.selectPhotosController animated:NO];
  [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
  [self refreshFromServer];
  [self reloadData];
  
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)reloadData
{
  DFSelectPhotosViewController *selectPhotosController = self.selectPhotosController;
  dispatch_async(dispatch_get_main_queue(), ^{
    [selectPhotosController setCollectionFeedObjects:[[DFPeanutFeedDataManager sharedManager]
                                                      privateStrandsByDateAscending:YES]];
  });
}

- (void)refreshFromServer
{
  [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFPrivateFeed completion:^{
  }];
}



#pragma mark - View Controller Delegates

- (void)selectPhotosViewController:(DFSelectPhotosViewController *)controller
     didFinishSelectingFeedObjects:(NSArray *)selectedFeedObjects
{
  if (selectedFeedObjects.count == 0) {
    [self dismissWithResult:DFCreateStrandResultAborted errorString:nil];
    return;
  }
  
  NSArray *suggestedContacts = [self suggestedContactsForFeedObjects:selectedFeedObjects];
  self.peoplePickerController = [[DFPeoplePickerViewController alloc]
                                 initWithSuggestedPeanutContacts:suggestedContacts];
  self.peoplePickerController.delegate = self;
  self.peoplePickerController.allowsMultipleSelection = YES;
  [self pushViewController:self.peoplePickerController animated:YES];
}

- (NSArray *)suggestedContactsForFeedObjects:(NSArray *)feedObjects
{
  NSArray *suggestedObjects = [self.selectPhotosController.selectPhotosController
             collectionFeedObjectsWithSelectedObjects];
  NSMutableOrderedSet *users = [NSMutableOrderedSet new];
  for (DFPeanutFeedObject *object in suggestedObjects) {
    [users addObjectsFromArray:object.actors];
  }
  NSArray *contacts = [users.array arrayByMappingObjectsWithBlock:^id(DFPeanutUserObject *user) {
    return [[DFPeanutContact alloc] initWithPeanutUser:user];
  }];
  
  return contacts;
}


- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  [self createStrand];
}


#pragma mark - Create Strand Logic

- (void)createStrand
{
  DFCreateStrandFlowViewController __weak *weakSelf = self;
  
  
  [SVProgressHUD show];
  
  NSArray *phoneNumbers = [self.peoplePickerController.selectedPeanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
    return contact.phone_number;
  }];
  
  [[DFPeanutFeedDataManager sharedManager]
   sharePhotoObjects:self.selectPhotosController.selectedObjects
   withPhoneNumbers:phoneNumbers
   success:^(NSArray *photos, NSArray *createdPhoneNumbers) {
     if (createdPhoneNumbers.count > 0) {
       [self sendTextToPhoneNumbers:createdPhoneNumbers];
     } else {
       [weakSelf dismissWithResult:DFCreateStrandResultSuccess errorString:nil];
     }
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:error.localizedDescription];
     DDLogError(@"%@ create failed: %@", weakSelf.class, error);
   }];
}

- (void)sendTextToPhoneNumbers:(NSArray *)phoneNumbers
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DFPeanutFeedObject *photo = self.selectPhotosController.selectPhotosController.selectedFeedObjects.firstObject;
    DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc] initWithRecipients:phoneNumbers locationString:nil date:photo.time_taken];
    if (smsvc && [DFSMSInviteStrandComposeViewController canSendText]) {
      // Some of the invitees aren't Strand users, send them a text
      smsvc.messageComposeDelegate = self;
      [self presentViewController:smsvc
                         animated:YES
                       completion:^{
                         [SVProgressHUD dismiss];
                       }];
    } else {
      [self dismissWithResult:DFCreateStrandResultSuccess errorString:nil];
    }
  });
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  
  [self dismissWithResult:DFCreateStrandResultSuccess
              errorString:(result == MessageComposeResultSent ? nil : @"Some invites not sent")];
}


- (void)dismissWithResult:(DFCreateStrandResult)result errorString:(NSString *)errorString
{
  [self logAnalyticsForResult:result errorString:errorString];
  [self.delegate createStrandFlowController:self
                        completedWithResult:result
                                     photos:self.selectPhotosController.selectedObjects
                                   contacts:self.peoplePickerController.selectedPeanutContacts];
  
  void (^completion)(void) = ^{
    if (result == DFCreateStrandResultSuccess) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (result == DFCreateStrandResultSuccess)
          [SVProgressHUD showSuccessWithStatus:errorString ? errorString : @"Sent!"];
        else if (result == DFCreateStrandResultFailure)
          [SVProgressHUD showErrorWithStatus:errorString];
      });
    }
  };
  
  [self.presentingViewController dismissViewControllerAnimated:YES completion:completion];
}

- (void)logAnalyticsForResult:(DFCreateStrandResult)result errorString:(NSString *)errorString
{
  NSMutableDictionary *analyticsInfo = [NSMutableDictionary new];
  [analyticsInfo addEntriesFromDictionary:self.extraAnalyticsInfo];
  
  if (errorString) {
    analyticsInfo[@"errorString"] = errorString;
  }
  
  NSString *analyticsResult;
  if (result == DFCreateStrandResultAborted) {
    analyticsResult = DFAnalyticsValueResultAborted;
    NSString *furthestReached = self.peoplePickerController ? @"peoplePicker" : @"photoPicker";
    analyticsInfo[@"furthestControllerReached"] = furthestReached;
  } else if (result == DFCreateStrandResultFailure) {
    analyticsResult = DFAnalyticsValueResultFailure;
  } else if (result == DFCreateStrandResultSuccess) {
    analyticsResult = DFAnalyticsValueResultSuccess;
  }
  NSUInteger numPhotos = self.selectPhotosController.selectedObjects.count;
  NSUInteger numPeople = self.peoplePickerController.selectedPeanutContacts.count;
  
  [DFAnalytics logCreateStrandFlowCompletedWithResult:analyticsResult
                                    numPhotosSelected:numPhotos
                                    numPeopleSelected:numPeople
                                            extraInfo:analyticsInfo];
}


- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}


/*
 * This is the same code as in DFFeedViewController, might want to abstract if we do this more
 */
+ (void)presentFeedObject:(DFPeanutFeedObject *)feedObject
  modallyInViewController:(UIViewController *)viewController
{
  DFCreateStrandFlowViewController *createStrandController = [[DFCreateStrandFlowViewController alloc]
                                                              initWithHighlightedPhotoCollection:feedObject];
  
  [viewController presentViewController:createStrandController animated:YES completion:nil];
}


@end
