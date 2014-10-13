//
//  DFPeoplePickerController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutContact.h"
#import "VENTokenField.h"

@class DFPeoplePickerViewController;

@protocol DFPeoplePickerDelegate <NSObject>

@required

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didFinishWithPickedContacts:(NSArray *)peanutContacts;

@optional
- (void)pickerController:(DFPeoplePickerViewController *)pickerController textDidChange:(NSString *)text;
- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         pickedContactsDidChange:(NSArray *)peanutContacts;


@end


@interface DFPeoplePickerViewController : UITableViewController <VENTokenFieldDelegate, VENTokenFieldDataSource>

@property (nonatomic, weak) NSObject<DFPeoplePickerDelegate>* delegate;
@property (nonatomic, retain) VENTokenField *tokenField;
@property (nonatomic, retain) NSArray *abSearchResults;
@property (nonatomic, retain) NSString *textNumberString;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (readonly, nonatomic, retain) NSArray *selectedPeanutContacts;


- (instancetype)initWithTokenField:(VENTokenField *)tokenField
                         tableView:(UITableView *)tableView;
- (instancetype)initWithTokenField:(VENTokenField *)tokenField
                   withPeanutUsers:(NSArray *)peanutUsers
                         tableView:(UITableView *)tableView;


@end
