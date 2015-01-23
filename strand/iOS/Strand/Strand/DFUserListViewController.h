//
//  DFUserListViewController.h
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"

@interface DFUserListViewController : DFPeoplePickerViewController

@property (nonatomic, retain) NSArray *users;

- (instancetype)initWithUsers:(NSArray *)users;

@end
