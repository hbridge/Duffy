//
//  DFSuggestionsPageViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"
#import "DFPeoplePickerViewController.h"
#import <MessageUI/MessageUI.h>
#import "DFCreateStrandFlowViewController.h"
#import "DFHomeSubViewController.h"



@interface DFSuggestionsPageViewController : UIPageViewController
<UIPageViewControllerDelegate, DFCreateStrandFlowViewControllerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic, retain) DFPeanutUserObject *userToFilter;
@property (nonatomic) DFHomeSubViewType preferredType;
@property (nonatomic) DFPhotoIDType startingPhotoID;
@property (nonatomic) DFPhotoIDType startingStrandID;

- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType;
- (instancetype)initWithPreferredType:(DFHomeSubViewType)preferredType photoID:(DFPhotoIDType)photoID strandID:(DFStrandIDType)strandID;

@end
