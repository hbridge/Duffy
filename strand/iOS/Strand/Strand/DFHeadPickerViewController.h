//
//  DFHeadPickerViewController.h
//  Strand
//
//  Created by Henry Bridge on 2/6/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFRecipientPickerViewController.h"
#import "DFProfileStackView.h"

@interface DFHeadPickerViewController : DFRecipientPickerViewController <DFProfileStackViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UIView *doneButtonWrapper;
@property (weak, nonatomic) IBOutlet UIView *doneButton;
@property (weak, nonatomic) IBOutlet UIScrollView *headScrollView;
@property (nonatomic, retain) DFProfileStackView *profileStackView;

@end
