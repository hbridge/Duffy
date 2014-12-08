//
//  DFNoTableItemsLabel.m
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNoTableItemsView.h"

@implementation DFNoTableItemsView

- (instancetype)initWithSuperView:(UIView *)superview
{
  self = [super init];
  if (self) {
    [self configureWithSuperView:superview];
  }
  return self;
}

- (void)awakeFromNib
{
  [self configureWithSuperView:self.superview];
  self.subtitleLabel.text = @"";
//  [self.titleLabel addObserver:self
//                    forKeyPath:@"text"
//                       options:NSKeyValueObservingOptionNew
//                       context:nil];
//  [self.subtitleLabel addObserver:self
//                    forKeyPath:@"text"
//                       options:NSKeyValueObservingOptionNew
//                       context:nil];
}

- (void)configureWithSuperView:(UIView *)superView
{
  self.titleLabel.text = @"No Results";
  [self setSuperView:superView];
}

- (void)setSuperView:(UIView *)superView
{
  if (self.superview != superView) {
    [superView addSubview:self];
  }
  CGRect frame = superView.frame;
  frame.size.height = frame.size.height / 2.0;
  self.frame = frame;
}

- (IBAction)buttonPressed:(id)sender {
  if (self.buttonHandler) self.buttonHandler();
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([[object class] isSubclassOfClass:[UILabel class]]) {
    [object sizeToFit];
  }
}
@end
