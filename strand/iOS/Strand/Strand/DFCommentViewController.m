//
//  DFCommentViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentViewController.h"

@interface DFCommentViewController ()

@end

@implementation DFCommentViewController

- (instancetype)initWithPhotoObject:(DFPeanutFeedObject *)photoObject
{
  self = [super init];
  if (self) {
    _photoObject = photoObject;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
}

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  cell.textLabel.text = @"Test";
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return @"Header";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  return @"Footer";
}

- (IBAction)sendButtonPressed:(id)sender {
}

- (IBAction)textDidChange:(UITextField *)sender {
}
@end
