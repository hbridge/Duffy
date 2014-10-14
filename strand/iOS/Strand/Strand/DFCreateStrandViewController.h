//
//  DFCreateStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectSuggestionsViewController.h"
#import "DFPeoplePickerViewController.h"
#import <MessageUI/MessageUI.h>


@interface DFCreateStrandViewController : DFSelectSuggestionsViewController <DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@end
