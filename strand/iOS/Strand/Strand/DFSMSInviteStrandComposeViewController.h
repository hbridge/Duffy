//
//  DFSMSInviteStrandComposeViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <MessageUI/MessageUI.h>

@interface DFSMSInviteStrandComposeViewController : MFMessageComposeViewController <MFMessageComposeViewControllerDelegate>

typedef void (^DFSMSComposeCompletionBlock)(MessageComposeResult result);

@property (nonatomic, copy) DFSMSComposeCompletionBlock completionBlock;

+ (void)showWithParentViewController:(UIViewController *)parentViewController
                        phoneNumbers:(NSArray *)phoneNumbers
                            fromDate:(NSDate *)date
                     completionBlock:(DFSMSComposeCompletionBlock)completionBlock;


- (instancetype)initWithRecipients:(NSArray *)recipients
                    locationString:(NSString *)locationString
                              date:(NSDate *)date;
- (instancetype)initWithRecipients:(NSArray *)recipients;




@end
