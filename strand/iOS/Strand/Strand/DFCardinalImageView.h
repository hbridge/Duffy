//
//  DFCardinalImageView.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFCardinalImageView;


@protocol DFCardinalImageViewDelegate <NSObject>

@required
- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
        buttonSelected:(UIButton *)button;


@optional
- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
              didBeginPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
              didMovePan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;
- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
              didEndPan:(UIPanGestureRecognizer *)panGesture
              translation:(CGPoint)translation;



@end


@interface DFCardinalImageView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (nonatomic, weak) id<DFCardinalImageViewDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (weak, nonatomic) IBOutlet UIImageView *overlayImageView;

- (IBAction)panGestureChanged:(UIPanGestureRecognizer *)sender;
- (void)resetView;

@end
