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
  [[DFPeanutFeedDataManager sharedManager] refreshPrivatePhotosFromServer:^{
  }];
}



#pragma mark - View Controller Delegates

- (void)selectPhotosViewController:(DFSelectPhotosViewController *)controller
     didFinishSelectingFeedObjects:(NSArray *)selectedFeedObjects
{
  if (selectedFeedObjects.count == 0) {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    NSString *furthestReached = self.peoplePickerController ? @"peoplePicker" : @"photoPicker";
    NSMutableDictionary *parameters = [@{@"furthestControllerReached" : furthestReached} mutableCopy];
    [parameters addEntriesFromDictionary:self.extraAnalyticsInfo];
    [DFAnalytics logCreateStrandFlowCompletedWithResult:DFAnalyticsValueResultAborted
                                      numPhotosSelected:self.selectPhotosController.selectedObjects.count
                                      numPeopleSelected:self.peoplePickerController.selectedPeanutContacts.count
                                              extraInfo:parameters];
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
  NSArray *suggestedObjects = [self.selectPhotosController.selectPhotosController
                               collectionFeedObjectsWithSelectedObjects];
  
  DFCreateStrandFlowViewController __weak *weakSelf = self;
  
  [SVProgressHUD show];
  [[DFPeanutFeedDataManager sharedManager]
   createNewStrandWithFeedObjects:self.selectPhotosController.selectedObjects
   createdFromSuggestions:suggestedObjects
   selectedPeanutContacts:self.peoplePickerController.selectedPeanutContacts
   success:^(DFPeanutStrand *createdStrand){
     [weakSelf sendInvitesForStrand:createdStrand
               toPeanutContacts:weakSelf.peoplePickerController.selectedPeanutContacts
                     suggestion:suggestedObjects.firstObject];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:error.localizedDescription];
     DDLogError(@"%@ create failed: %@", weakSelf.class, error);
   }];
}

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
                  suggestion:(DFPeanutFeedObject *)suggestion
{
  DFCreateStrandFlowViewController __weak *weakSelf = self;
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
         [weakSelf dismissWithErrorString:nil];
       }
     });
   } failure:^(NSError *error) {
     [weakSelf dismissWithErrorString:@"Invite failed"];
     DDLogError(@"%@ failed to invite to strand: %@, error: %@",
                weakSelf.class, peanutStrand, error);
   }];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissWithErrorString:(result == MessageComposeResultSent ? nil : @"Some invites not sent")];
}


- (void)dismissWithErrorString:(NSString *)errorString
{
  DFCreateStrandFlowViewController __weak *weakSelf = self;
  void (^completion)(void) = ^{
    if (!errorString) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Sent!"];
      });
      [DFAnalytics logCreateStrandFlowCompletedWithResult:DFAnalyticsValueResultSuccess
                                        numPhotosSelected:weakSelf.selectPhotosController.selectedObjects.count
                                        numPeopleSelected:weakSelf.peoplePickerController.selectedPeanutContacts.count
                                                extraInfo:weakSelf.extraAnalyticsInfo];
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:errorString];
      });
      NSMutableDictionary *params = [@{@"errorString" : errorString} mutableCopy];
      [params addEntriesFromDictionary:self.extraAnalyticsInfo];
      [DFAnalytics logCreateStrandFlowCompletedWithResult:DFAnalyticsValueResultFailure
                                        numPhotosSelected:weakSelf.selectPhotosController.selectedObjects.count
                                        numPeopleSelected:weakSelf.peoplePickerController.selectedPeanutContacts.count
                                                extraInfo:params];
    }
  };
  
  [self.presentingViewController dismissViewControllerAnimated:YES completion:completion];
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
  
  createStrandController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                              initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:createStrandController
                                                              action:@selector(dismissWhenPresented)];
  
  
  [viewController presentViewController:createStrandController animated:YES completion:nil];
  
}

- (void)dismissWhenPresented
{
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


@end
