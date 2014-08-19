//
//  DFAddContactViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAddContactViewController.h"
#import "Formkit.h"
#import "DFContactsStore.h"
#import "UIAlertView+DFHelpers.h"
#import "DFAnalytics.h"

@interface DFAddContactViewController ()

@property (nonatomic, retain) FKFormModel *formModel;

@end

@implementation DFAddContactViewController

- (id)init
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.navigationItem.backBarButtonItem.title = @"Cancel";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                              target:self
                                              action:@selector(donePressed:)];
    
    self.contact = [[DFPeanutContact alloc] init];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureForm];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)configureForm
{
  self.formModel = [FKFormModel formTableModelForTableView:self.tableView
                                      navigationController:self.navigationController];
  
  self.formModel.labelTextColor = [UIColor blackColor];
  self.formModel.valueTextColor = [UIColor lightGrayColor];
  
  [FKFormMapping mappingForClass:[DFPeanutContact class] block:^(FKFormMapping *mapping) {
    // Info
    [mapping sectionWithTitle:@"Information" identifier:@"info"];
    [mapping mapAttribute:@"name" title:@"Name"
                     type:FKFormAttributeMappingTypeText
             keyboardType:UIKeyboardTypeNamePhonePad];
    [mapping mapAttribute:@"phone_number"
                    title:@"Phone"
                     type:FKFormAttributeMappingTypeText
             keyboardType:UIKeyboardTypePhonePad];
    
    [mapping
     validationForAttribute:@"name"
     validBlock:^BOOL(NSString *value, id object) {
       return (value.length > 0 && value.length < 20);
     } errorMessageBlock:^NSString *(id value, id object) {
       return @"Please enter a 1 to 20 character name";
     }];
    [mapping
     validationForAttribute:@"phone_number"
     validBlock:^BOOL(NSString *value, id object) {
       if (value.length != 10) return false;
       NSRange nonDigitRange = [value rangeOfCharacterFromSet:[[NSCharacterSet
                                                                decimalDigitCharacterSet] invertedSet]];
       if (nonDigitRange.location != NSNotFound) return false;
       
       return true;
     } errorMessageBlock:^NSString *(id value, id object) {
       return @"Please enter a 10-digit phone number";
     }];
    
    [self.formModel registerMapping:mapping];
  }];
  
  [self.formModel loadFieldsWithObject:self.contact];
}

- (void)donePressed:(id)sender
{
  [self.formModel validateForm];
  if (self.formModel.invalidAttributes.count > 0) {
    [UIAlertView showSimpleAlertWithTitle:@"Invalid Entry"
                            formatMessage:@"You have entered invalid information.  Please try again."];
    [DFAnalytics logAddContactCompletedWithResult:@"ValidationFailure"];
    return;
  }

  [DFAnalytics logAddContactCompletedWithResult:@"Success"];
  [self.formModel save];
  [[DFContactsStore sharedStore]
   createContactWithName:self.contact.name
   phoneNumberString:self.contact.phone_number];
  
  [self.navigationController popViewControllerAnimated:YES];
}



@end
