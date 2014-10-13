//
//  DFCreateStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeoplePickerViewController.h"
#import "DFPeanutFeedObject.h"
#import "VENTokenField.h"
#import <MessageUI/MessageUI.h>
#import "DFSelectPhotosController.h"


@interface DFCreateStrandViewController : UIViewController <UIScrollViewDelegate, UICollectionViewDelegateFlowLayout, DFSelectPhotosControllerDelegate, DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectAllButton;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionsObject;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions;
- (IBAction)selectAllButtonPressed:(UIButton *)sender;


@end
