//
//  DFNavigationbar.m
//  Strand
//
//  Created by Henry Bridge on 7/27/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationBar.h"
#import "DFStrandConstants.h"
#import "DFOverlayViewController.h"

@interface DFNavigationBar()

@property (nonatomic, retain) UIWindow *overlayWindow;
@property (nonatomic, retain) DFOverlayViewController *overlayVC;

@end

@implementation DFNavigationBar

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureView];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self configureView];
  }
  return self;
}

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configureView];
}

- (void)configureView
{
  self.barTintColor = [DFStrandConstants defaultBackgroundColor];
  self.tintColor = [DFStrandConstants defaultBarForegroundColor];
  self.titleTextAttributes = @{
                                             NSForegroundColorAttributeName:
                                               [DFStrandConstants defaultBarForegroundColor]
                                             };
  self.translucent = NO;
}

- (void)layoutSubviews
{
  [super setFrame:CGRectMake(self.frame.origin.x, 0, self.frame.size.width, 64)];
  [super layoutSubviews];
}

- (void)setItemAlpha:(CGFloat)alpha
{
  for (UINavigationItem *item in self.items) {
    [item.leftBarButtonItems enumerateObjectsUsingBlock:
     ^(UIBarButtonItem* item, NSUInteger i, BOOL *stop) {
       item.customView.alpha = alpha;
     }];
    [item.rightBarButtonItems enumerateObjectsUsingBlock:
     ^(UIBarButtonItem* item, NSUInteger i, BOOL *stop) {
       item.customView.alpha = alpha;
     }];
    item.titleView.alpha = alpha;
    self.tintColor =
    [self.tintColor colorWithAlphaComponent:alpha];
  }
}

@end
