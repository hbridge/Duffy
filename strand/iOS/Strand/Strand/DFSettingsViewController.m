//
//  DFSettingsViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettingsViewController.h"
#import "FormKit.h"
#import "DFSettings.h"
#import "DFWebViewController.h"
#import "DFDiagnosticInfoMailComposeController.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) FKFormModel *formModel;
@property (nonatomic, retain) DFSettings *settings;

@end

@implementation DFSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.settings = [[DFSettings alloc] init];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureForm];
}

- (void)configureForm
{
  self.formModel = [FKFormModel formTableModelForTableView:self.tableView
                                      navigationController:self.navigationController];
  
  self.formModel.labelTextColor = [UIColor blackColor];
  self.formModel.valueTextColor = [UIColor lightGrayColor];
  
  [FKFormMapping mappingForClass:[DFSettings class] block:^(FKFormMapping *mapping) {
    [mapping sectionWithTitle:@"Information" identifier:@"info"];
    [mapping mapAttribute:@"version" title:@"Version" type:FKFormAttributeMappingTypeText];
    
    [mapping sectionWithTitle:@"Profile" identifier:@"profile"];
    [mapping mapAttribute:@"displayName" title:@"Display Name" type:FKFormAttributeMappingTypeText];
    
    [mapping sectionWithTitle:@"Support" identifier:@"support"];
    [mapping button:@"Help" identifier:@"helpInfo" handler:^(id object) {
      DFWebViewController *webviewController =
      [[DFWebViewController alloc]
       initWithURL:[NSURL URLWithString:@"http://www.duffyapp.com/strand/support"]];
      [self.navigationController pushViewController:webviewController animated:YES];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Report Issue" identifier:@"reportIssue" handler:^(id object) {
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeIssue];
      [self presentViewController:mailComposer animated:YES completion:nil];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Send Feedback" identifier:@"sendFeedback" handler:^(id object) {
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeFeedback];
      [self presentViewController:mailComposer animated:YES completion:nil];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];

    
    [self.formModel registerMapping:mapping];
  }];
  
  [self.formModel loadFieldsWithObject:self.settings];
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

@end
