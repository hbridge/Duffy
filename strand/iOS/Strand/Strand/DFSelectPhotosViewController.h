//
//  DFSelectPhotosViewController
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>
#import "DFGalleryCollectionViewFlowLayout.h"
#import "DFSelectPhotosController.h"

@class DFSelectPhotosViewController;

@protocol DFSelectPhotosViewControllerDelegate <NSObject>

- (void)selectPhotosViewController:(DFSelectPhotosViewController *)controller
     didFinishSelectingFeedObjects:(NSArray *)selectedFeedObjects;

@end


@interface DFSelectPhotosViewController : UIViewController<DFImageDataSourceDelegate, DFSelectPhotosControllerDelegate, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, retain) NSArray *collectionFeedObjects;
@property (nonatomic, weak) id <DFSelectPhotosViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIView *doneWrapper;

@property (nonatomic) BOOL allowsNilSelection;
@property (nonatomic, retain) DFSelectPhotosController *selectPhotosController;
@property (nonatomic, retain) DFPeanutFeedObject *highlightedFeedObject;



- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects;
- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                        highlightedFeedObject:(DFPeanutFeedObject *)highlightedObject;
- (IBAction)doneButtonPressed:(UIButton *)sender;
- (NSArray *)selectedObjects;


@end
