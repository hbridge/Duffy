//
//  DFswipableButtonView.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFSwipableButtonView;


@protocol DFSwipableButtonViewDelegate <NSObject>

@required
- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
            buttonSelected:(UIButton *)button
                   isSwipe:(BOOL)isSwipe;


@optional
- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
              didBeginPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
              didMovePan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
              didEndPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;



@end


@interface DFSwipableButtonView : UIView

@property (weak, nonatomic) IBOutlet UIView *centerView;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (weak, nonatomic) IBOutlet UIButton *otherButton;
@property (nonatomic, weak) id<DFSwipableButtonViewDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (weak, nonatomic) IBOutlet UIImageView *overlayImageView;
@property (nonatomic) BOOL yesEnabled;
@property (nonatomic) BOOL noEnabled;

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) UILabel *labelView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *buttonWrapperHeightConstraint;

- (void)configureWithShowsOther:(BOOL)showsOther;
- (IBAction)panGestureChanged:(UIPanGestureRecognizer *)sender;
- (void)resetView;

- (void)configureToUseImage;
- (void)configureToUseView:(UIView *)view;
- (void)setButtonsHidden:(BOOL)hidden;

@end
