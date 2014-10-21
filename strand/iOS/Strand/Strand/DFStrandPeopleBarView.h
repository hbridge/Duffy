//
//  DFStrandPeopleBarView.h
//  Strand
//
//  Created by Henry Bridge on 10/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFStrandPeopleBarView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *peopleIcon;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *invitedLabel;
@property (weak, nonatomic) IBOutlet UIImageView *invitedIcon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *peopleToInviteConstraint;

- (void)configureWithStrandPostsObject:(DFPeanutFeedObject *)strandPostsObject;

@end
