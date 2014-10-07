//
//  DFAcceptInviteViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"
#import "DFSelectPhotosController.h"

@interface DFAcceptInviteViewController : UIViewController <DFSelectPhotosControllerDelegate>

/* invite area */
@property (weak, nonatomic) IBOutlet UIView *inviteWrapper;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *invitedCollectionView;

/* start match button and activity */
@property (weak, nonatomic) IBOutlet UIView *matchButtonWrapper;
@property (weak, nonatomic) IBOutlet UIView *matchingActivityWrapper;

/* match results*/
@property (weak, nonatomic) IBOutlet UIView *matchResultsView;
@property (weak, nonatomic) IBOutlet UILabel *matchResultsTitleLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *matchedCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *matchedFlowLayout;

/* swap photos bottom bar */
@property (weak, nonatomic) IBOutlet UIView *swapPhotosBar;
@property (weak, nonatomic) IBOutlet UIButton *swapPhotosButton;

- (instancetype)initWithInviteObject:(DFPeanutFeedObject *)inviteObject;
- (IBAction)matchButtonPressed:(UIButton *)sender;
- (IBAction)swapPhotosButtonPressed:(id)sender;


@end
