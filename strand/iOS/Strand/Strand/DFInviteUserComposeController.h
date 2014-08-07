//
//  DFInviteUserComposeControllerViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <MessageUI/MessageUI.h>

@interface DFInviteUserComposeController : MFMessageComposeViewController <MFMessageComposeViewControllerDelegate>

@property (nonatomic) MessageComposeResult result;
- (void)loadMessageWithCompletion:(void(^)(NSError *))messageLoadCompletion;

@end
