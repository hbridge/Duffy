//
//  DFInviteStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRecipientPickerViewController.h"
#import "DFPeanutFeedObject.h"
#import <MessageUI/MessageUI.h>

@interface DFInviteStrandViewController : DFRecipientPickerViewController <DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic) DFPeanutFeedObject *photoObject;

@end
