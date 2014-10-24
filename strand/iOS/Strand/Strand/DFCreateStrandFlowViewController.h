//
//  DFCreateStrandFlowViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFSelectPhotosViewController.h"
#import "DFPeoplePickerViewController.h"
#import <MessageUI/MessageUI.h>

@interface DFCreateStrandFlowViewController : DFNavigationController <DFSelectPhotosViewControllerDelegate, DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic, retain) DFSelectPhotosViewController *selectPhotosController;
@property (nonatomic, retain) DFPeoplePickerViewController *peoplePickerController;
@property (nonatomic, retain) DFPeanutFeedObject *highlightedCollection;

- (instancetype)initWithHighlightedPhotoCollection:(DFPeanutFeedObject *)highlightedCollection;
- (void)refreshFromServer;

@end
