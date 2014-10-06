//
//  DFAcceptInviteViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFAcceptInviteViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIView *inviteWrapper;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *invitedCollectionView;
- (IBAction)matchButtonPressed:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIView *matchButtonWrapper;
@property (weak, nonatomic) IBOutlet UIView *matchingActivityWrapper;
@property (weak, nonatomic) IBOutlet UICollectionView *matchedCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *matchedFlowLayout;

- (instancetype)initWithInviteObject:(DFPeanutFeedObject *)inviteObject;

@end
