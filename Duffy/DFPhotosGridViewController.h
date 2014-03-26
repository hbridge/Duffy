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

@property (nonatomic, retain) NSArray *photos;
@property (nonatomic) CGFloat photoSquareSize;
@property (nonatomic) CGFloat photoSpacing;

@end
