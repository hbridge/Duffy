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


@interface DFPeoplePickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,UISearchBarDelegate, UISearchDisplayDelegate>

@property (nonatomic, weak) NSObject<DFPeoplePickerDelegate>* delegate;
@property (nonatomic, retain) NSString *textNumberString;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, retain) NSArray *suggestedPeanutContacts;
@property (readonly, nonatomic, retain) NSArray *selectedPeanutContacts;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *doneButtonWrapper;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;


- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts;
- (IBAction)sendButtonPressed:(id)sender;

@end
