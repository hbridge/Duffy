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
  DFPeanutStrand *peanutStrand = [[DFPeanutStrand alloc] init];
  peanutStrand.id = @(self.sectionObject.id);
  [self sendInvitesForStrand:peanutStrand
            toPeanutContacts:self.pickedContacts];
}

- (void)cancelButtonPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
{
  [self.inviteAdapter
   sendInvitesForStrand:peanutStrand
   toPeanutContacts:peanutContacts
   inviteLocationString:self.sectionObject.location
   invitedPhotosDate:self.sectionObject.time_taken
   success:^(DFSMSInviteStrandComposeViewController *vc) {
     vc.messageComposeDelegate = self;
     if (vc) {
       [self presentViewController:vc
                          animated:YES
                        completion:nil];
       [SVProgressHUD dismiss];
     } else {
       [self dismissWithErrorString:nil];
     }
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
     DDLogError(@"%@ failed to invite to strand: %@, error: %@",
                self.class, peanutStrand, error);
   }];
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
  [self.presentingViewController
   dismissViewControllerAnimated:YES
   completion:^{
     if (!errorString) {
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [SVProgressHUD showSuccessWithStatus:@"Sent!"];
       });
     } else {
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [SVProgressHUD showErrorWithStatus:errorString];
       });
     }
   }];
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}

@end
