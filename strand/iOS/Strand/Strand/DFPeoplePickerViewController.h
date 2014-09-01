//
//  DFPeoplePickerController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutContact.h"

@class DFPeoplePickerViewController;

@protocol DFPeoplePickerDelegate <NSObject>

@required

- (void)pickerController:(DFPeoplePickerViewController *)pickerController didPickContact:(DFPeanutContact *)contact;

@end


@interface DFPeoplePickerViewController : UITableViewController <UITextFieldDelegate>

@property (nonatomic, weak) NSObject<DFPeoplePickerDelegate>* delegate;

@property (nonatomic, retain) UITextField *toTextField;
@property (nonatomic, retain) NSArray *abSearchResults;
@property (nonatomic, retain) NSString *textNumberString;

@end
