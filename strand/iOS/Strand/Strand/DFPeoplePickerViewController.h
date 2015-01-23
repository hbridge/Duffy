//
//  DFPeoplePickerController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutContact.h"
#import "DFNoTableItemsView.h"
#import "DFSection.h"
#import "DFPeoplePickerSecondaryAction.h"




@class DFPeoplePickerViewController;

@protocol DFPeoplePickerDelegate <NSObject>

@required

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didFinishWithPickedContacts:(NSArray *)peanutContacts;

@optional
- (void)pickerController:(DFPeoplePickerViewController *)pickerController textDidChange:(NSString *)text;
- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         pickedContactsDidChange:(NSArray *)peanutContacts;
- (void)pickerController:(DFPeoplePickerViewController *)pickerController
           contactTapped:(DFPeanutContact *)contact;

@end


@interface DFPeoplePickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,UISearchBarDelegate, UISearchDisplayDelegate>


@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *doneButtonWrapper;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

#pragma mark - Delegate

@property (nonatomic, weak) id<DFPeoplePickerDelegate> delegate;

#pragma mark - Configuration

@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, retain) NSArray *selectedContacts;
@property (nonatomic, retain) NSArray *notSelectableContacts;
@property (nonatomic, retain) NSString *notSelectableReason;
@property (nonatomic, retain) NSString *doneButtonActionText;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;
@property (nonatomic) BOOL disableContactsUpsell;
@property (nonatomic, retain) NSString *textNumberString;

- (void)setSections:(NSArray *)sections;
- (void)setSecondaryAction:(DFPeoplePickerSecondaryAction *)secondaryAction
                forSection:(DFSection *)section;
- (void)removeSearchBar;

+ (DFSection *)allContactsSection;

@end
