//
//  DFTimelineViewController.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotosGridViewController : UIViewController
    <UICollectionViewDataSource, UICollectionViewDelegate,
    UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) UICollectionViewFlowLayout *flowLayout;

@property (readonly, nonatomic, retain) NSDictionary *itemsBySection;
@property (readonly, nonatomic, retain) NSArray *sectionNames;
@property (nonatomic) CGFloat itemSquareSize;
@property (nonatomic) CGFloat itemSpacing;


- (CGRect)frameForCellAtIndexPath:(NSIndexPath *)indexPath;
- (void)scrollToBottom;
- (void)scrollToTop;
- (void)setSectionNames:(NSArray *)sectionNames
         itemsBySection:(NSDictionary *)photosBySection;

@end
