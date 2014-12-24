//
//  DFInviteStrandViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteStrandViewController.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "SVProgressHUD.h"
#import "DFAnalytics.h"
#import "DFPeanutFeedDataManager.h"

@interface DFInviteStrandViewController ()

@property (nonatomic, retain) NSArray *pickedContacts;
@property (nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;

@end

@implementation DFInviteStrandViewController

@synthesize inviteAdapter = _inviteAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configure];
  }
  return self;
}

- (void)setDelegate:(NSObject<DFPeoplePickerDelegate> *)delegate
{
  if (delegate != self) [NSException raise:@"Not supported"
                                    format:@"DFInviteStrandViewController must be its own peoplePickerDelegate"];
  [super setDelegate:delegate];
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      [self configure];
    }
    return self;
}


- (void)configure
{
  self.delegate = self;
  self.allowsMultipleSelection = YES;
  
  self.navigationItem.title = @"People";
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                           target:self
                                           action:@selector(cancelButtonPressed:)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - DFPeoplePicker Delegate

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  DDLogVerbose(@"picked contacts: %@", peanutContacts);
  self.pickedContacts = peanutContacts;
  [SVProgressHUD show];
  
  NSArray *phoneNumbers = [peanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
    return contact.phone_number;
  }];
  [[DFPeanutFeedDataManager sharedManager]
   addUsersWithPhoneNumbers:phoneNumbers
   toShareInstanceID:self.photoObject.share_instance.longLongValue
   success:^(NSArray *numbersToText) {
     [self sendTextToPhoneNumbers:numbersToText];
     
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:error.localizedDescription];
     DDLogError(@"%@ adding users failed: %@", self.class, error);
   }];
}

- (void)cancelButtonPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendTextToPhoneNumbers:(NSArray *)phoneNumbers
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc]
                                                     initWithRecipients:phoneNumbers
                                                     locationString:nil
                                                     date:self.photoObject.time_taken];
    if (smsvc && [DFSMSInviteStrandComposeViewController canSendText]) {
      // Some of the invitees aren't Strand users, send them a text
      smsvc.messageComposeDelegate = self;
      [self presentViewController:smsvc
                         animated:YES
                       completion:^{
                         [SVProgressHUD dismiss];
                       }];
    } else {
      [self dismissWithErrorString:nil];
    }
  });
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  if (result == MessageComposeResultSent) {
    [self dismissWithErrorString:nil];
  } else {
    [self dismissWithErrorString:@"Cancelled"];
  }
}

- (void)dismissWithErrorString:(NSString *)errorString
{
  DFVoidBlock completionBlock = ^{
    if (!errorString) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Sent!"];
      });
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:errorString];
      });
    }
  };
  
  
 
  [self.presentingViewController
   dismissViewControllerAnimated:YES
   completion:completionBlock];

}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}

@end
