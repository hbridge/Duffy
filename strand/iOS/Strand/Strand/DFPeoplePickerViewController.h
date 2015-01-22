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

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didFinishWithPickedContacts:(NSArray *)peanutContacts;

@optional
- (void)pickerController:(DFPeoplePickerViewController *)pickerController textDidChange:(NSString *)text;
- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         pickedContactsDidChange:(NSArray *)peanutContacts;

@end


@interface DFPeoplePickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,UISearchBarDelegate, UISearchDisplayDelegate>


@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *doneButtonWrapper;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

#pragma mark - Delegate

@property (nonatomic, weak) NSObject<DFPeoplePickerDelegate>* delegate;

#pragma mark - Configuration

@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, retain) NSArray *suggestedPeanutContacts;
@property (readonly, nonatomic, retain) NSArray *selectedPeanutContacts;
@property (nonatomic, retain) NSArray *notSelectableContacts;
@property (nonatomic, retain) NSString *notSelectableReason;
@property (nonatomic) BOOL hideFriendsSection;
@property (nonatomic, retain) NSString *doneButtonActionText;

@property (nonatomic, retain) NSString *textNumberString;

- (instancetype)initWithSuggestedPeanutUsers:(NSArray *)suggestedPeanutedUsers;
- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts;
- (instancetype)initWithSelectedPeanutContacts:(NSArray *)selectedPeanutContacts;
- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts
                    notSelectablePeanutContacts:(NSArray *)notSelectableContacts
                            notSelectableReason:(NSString *)notSelectableReason;

@end
