//
//  DFInviteFriendViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFPeoplePickerViewController.h"

@interface DFInviteFriendViewController : DFPeoplePickerViewController <DFPeoplePickerDelegate>

@property (nonatomic) BOOL showExistingFriendsSection;

@end
