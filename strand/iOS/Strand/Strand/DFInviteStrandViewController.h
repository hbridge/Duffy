//
//  DFInviteStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"
#import "DFPeanutFeedObject.h"
#import <MessageUI/MessageUI.h>

@interface DFInviteStrandViewController : DFPeoplePickerViewController <DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic, retain) DFPeanutFeedObject *sectionObject;

@end
