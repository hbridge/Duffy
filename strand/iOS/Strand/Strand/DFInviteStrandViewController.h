//
//  DFInviteStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRecipientPickerViewController.h"
#import "DFPeanutFeedObject.h"

@interface DFInviteStrandViewController : DFRecipientPickerViewController <DFPeoplePickerDelegate>

@property (nonatomic) DFPeanutFeedObject *photoObject;

@end
