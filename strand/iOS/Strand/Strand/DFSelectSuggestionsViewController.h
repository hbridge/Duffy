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

/* Array of DFPeanutFeedObjects that are section objects */
@property (nonatomic, retain) NSArray *suggestedSections;
@property (nonatomic) NSUInteger numPhotosPerRow;

@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;

- (instancetype)initWithSuggestions:(NSArray *)suggestedSections;
- (IBAction)selectAllButtonPressed:(UIButton *)sender;


@end
