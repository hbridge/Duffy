//
//  DFSMSInviteStrandComposeViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <MessageUI/MessageUI.h>

@interface DFSMSInviteStrandComposeViewController : MFMessageComposeViewController <MFMessageComposeViewControllerDelegate>

- (instancetype)initWithRecipients:(NSArray *)recipients;

@end
