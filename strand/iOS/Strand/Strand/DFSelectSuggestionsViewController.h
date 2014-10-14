//
//  DFAddPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"
#import "DFSelectPhotosController.h"

@interface DFSelectSuggestionsViewController : UIViewController <DFSelectPhotosControllerDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectAllButton;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionsObject;
@property (nonatomic) NSUInteger numPhotosPerRow;

- (instancetype)initWithSuggestions:(DFPeanutFeedObject *)suggestions;
- (IBAction)selectAllButtonPressed:(UIButton *)sender;


@end
