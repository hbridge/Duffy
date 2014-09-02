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

@interface DFInviteStrandViewController ()

@property (nonatomic, retain) NSArray *pickedContacts;

@end

@implementation DFInviteStrandViewController

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
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                           target:self
                                           action:@selector(cancelButtonPressed:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self
                                            action:@selector(doneButtonPressed:)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - DFPeoplePicker Delegate

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didPickContacts:(NSArray *)peanutContacts
{
  DDLogVerbose(@"picked contacts: %@", peanutContacts);
  self.pickedContacts = peanutContacts;
}

- (void)cancelButtonPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneButtonPressed:(id)sender
{
  DDLogVerbose(@"done pressed for section: %@contacts: %@", self.sectionObject, self.pickedContacts);
  NSMutableArray *invites = [NSMutableArray new];
  for (DFPeanutContact *contact in self.pickedContacts) {
    DFPeanutStrandInvite *invite = [[DFPeanutStrandInvite alloc] init];
    invite.user = @([[DFUser currentUser] userID]);
    invite.phone_number = contact.phone_number;
    invite.strand = @(self.sectionObject.id);
    [invites addObject:invite];
  }
  
  DFPeanutStrandInviteAdapter *inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  [inviteAdapter
   postInvites:invites
   success:^(NSArray *resultObjects) {
     [self dismissViewControllerAnimated:YES completion:^{
       [SVProgressHUD showSuccessWithStatus:@"Success!"];
     }];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
   }];
  
  
}

@end
