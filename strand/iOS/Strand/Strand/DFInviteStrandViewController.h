//
//  DFInviteStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"
#import "DFPeanutSearchObject.h"

@interface DFInviteStrandViewController : DFPeoplePickerViewController <DFPeoplePickerDelegate>

@property (nonatomic, retain) DFPeanutSearchObject *sectionObject;

@end
