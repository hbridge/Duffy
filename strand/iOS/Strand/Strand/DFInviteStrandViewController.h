//
//  DFInviteStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFHeadPickerViewController.h"
#import "DFPeanutFeedObject.h"

@interface DFInviteStrandViewController : DFHeadPickerViewController <DFPeoplePickerDelegate>

@property (nonatomic) DFPeanutFeedObject *photoObject;

@end
