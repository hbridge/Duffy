//
//  DFRecipientPickerViewController.h
//  Strand
//
//  Created by Henry Bridge on 1/22/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"

@interface DFRecipientPickerViewController : DFPeoplePickerViewController

- (instancetype)initWithSelectedPeanutContacts:(NSArray *)selectedPeanutContacts;
- (instancetype)initWithSuggestedPeanutUsers:(NSArray *)suggestedPeanutedUsers;
- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts;
- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts
                    notSelectablePeanutContacts:(NSArray *)notSelectableContacts
                            notSelectableReason:(NSString *)notSelectableReason;

@end
