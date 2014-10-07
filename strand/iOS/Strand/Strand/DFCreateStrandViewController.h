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


@interface DFCreateStrandViewController : UIViewController <UIScrollViewDelegate, UICollectionViewDelegateFlowLayout, DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate, DFSelectPhotosControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *searchBarWrapperView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, retain) VENTokenField *tokenField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *swapBarWrapper;
@property (weak, nonatomic) IBOutlet UIButton *swapPhotosButton;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionsObject;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions;
- (IBAction)swapPhotosButtonPressed:(UIButton *)sender;


@end
