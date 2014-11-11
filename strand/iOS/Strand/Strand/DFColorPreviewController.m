//
//  DFColorPreviewController.m
//  Strand
//
//  Created by Henry Bridge on 11/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFColorPreviewController.h"
#import "DFPersonSelectionTableViewCell.h"
#import "Strand-Swift.h"

@interface DFColorPreviewController ()

@end

@implementation DFColorPreviewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
}

- (void)configureTableView:(UITableView *)tableView
{
  self.tableView.dataSource = self;
  [tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]] forCellReuseIdentifier:@"cell"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 29;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  int value = (65 + (int)indexPath.row);
  NSString *name = [NSString stringWithFormat:@"%c", (char)value];
  if (indexPath.row > 25) {
    NSUInteger index = indexPath.row - 26;
    name = @[@"Aseem", @"Derek", @"Henry"][index];
    value = 0;
    for (NSUInteger i = 0; i < name.length; i++) {
      value += [name characterAtIndex:i];
    }
  }

  cell.profilePhotoStackView.names = @[name];
  cell.nameLabel.text = name;
  cell.subtitleLabel.text = [NSString stringWithFormat:@"Color: %d",
                             (int)(value % [[DFStrandConstants profilePhotoStackColors] count])];
  
  if (!cell) [NSException raise:@"nil cell" format:@"nil cell"];
  return cell;
}

@end
