//
//  DFSelectPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutSearchObject.h"
#import "VENTokenField.h"
#import "DFPeoplePickerViewController.h"

@interface DFSelectPhotosViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate,UIScrollViewDelegate, DFPeoplePickerDelegate>

@property (nonatomic, retain) DFPeanutSearchObject *suggestedSectionObject;
@property (nonatomic, retain) DFPeanutSearchObject *sharedSectionObject;

@property (weak, nonatomic) IBOutlet UIView *searchBarWrapperView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, retain) VENTokenField *tokenField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic) BOOL showsToField;

- (instancetype)initWithTitle:(NSString *)title
                 showsToField:(BOOL)showsToField
       suggestedSectionObject:(DFPeanutSearchObject *)suggestedSectionObject
          sharedSectionObject:(DFPeanutSearchObject *)sharedSectionObject;
- (IBAction)collectionViewTapped:(id)sender;

@end
