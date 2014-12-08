//
//  DFswipableButtonImageView.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFSwipableButtonImageView;


@protocol DFSwipableButtonImageViewDelegate <NSObject>

@required
- (void)swipableButtonImageView:(DFSwipableButtonImageView *)swipableButtonImageView
        buttonSelected:(UIButton *)button;


@optional
- (void)swipableButtonImageView:(DFSwipableButtonImageView *)swipableButtonImageView
              didBeginPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)swipableButtonImageView:(DFSwipableButtonImageView *)swipableButtonImageView
              didMovePan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)swipableButtonImageView:(DFSwipableButtonImageView *)swipableButtonImageView
              didEndPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;



@end


@interface DFSwipableButtonImageView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (nonatomic, weak) id<DFSwipableButtonImageViewDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (weak, nonatomic) IBOutlet UIImageView *overlayImageView;
@property (nonatomic) BOOL yesEnabled;
@property (nonatomic) BOOL noEnabled;

- (IBAction)panGestureChanged:(UIPanGestureRecognizer *)sender;
- (void)resetView;

@end
