//
//  DFDiagnosticReporter.h
//  Duffy
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MessageUI/MFMailComposeViewController.h>

typedef enum {
  DFMailTypeIssue,
  DFMailTypeFeedback
} DFMailType;

@interface DFDiagnosticInfoMailComposeController : MFMailComposeViewController
<MFMailComposeViewControllerDelegate>

- (instancetype)initWithMailType:(DFMailType)mailType;

@end
