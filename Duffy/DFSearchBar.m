//
//  DFSearchBar.m
//  Duffy
//
//  Created by Henry Bridge on 5/21/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchBar.h"

@interface DFSearchBar()

@property (nonatomic, retain) NSLayoutConstraint *textFieldCancelConstraint;

@end

@implementation DFSearchBar


- (void)awakeFromNib
{
  self.textField.delegate = self;
  [self.textField addTarget:self action:@selector(textFieldSearchButtonClicked:)
           forControlEvents:UIControlEventEditingDidEndOnExit];
  [self.textField addTarget:self action:@selector(textChanged:)
           forControlEvents:UIControlEventEditingChanged];
  self.text = self.defaultQuery;
  UIFont *newFont = [UIFont fontWithName:@"ProximaNova-Regular" size:19.0];
  self.textField.font = newFont;
  self.cancelButton.titleLabel.font = newFont;
  [self.cancelButton sizeToFit];
}

- (void)setText:(NSString *)text
{
  self.textField.text = text;
  [self.delegate searchBar:self textDidChange:text];
}

- (NSString *)text
{
  return self.textField.text;
}

- (void)setDefaultQuery:(NSString *)defaultQuery
{
  NSString *previousDefault = _defaultQuery;
  _defaultQuery = defaultQuery;
  if ([self.text isEqualToString:@""] || [self.text isEqualToString:previousDefault]) {
    self.text = defaultQuery;
  }
}

- (void)setPlaceholder:(NSString *)placeholderText
{
  self.textField.placeholder = placeholderText;
}

- (NSString *)placeholder
{
  return self.textField.placeholder;
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated
{
  _showsCancelButton = showsCancelButton;
  
  if (showsCancelButton) {
    self.cancelButton.hidden = NO;
    self.textFieldCancelConstraint = [NSLayoutConstraint constraintWithItem:self.cancelButton
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.textField
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0
                                                                   constant:8.0];
    [self addConstraint:self.textFieldCancelConstraint];
  } else {
    self.cancelButton.hidden = YES;
    [self removeConstraint:self.textFieldCancelConstraint];
  }
}

- (void)setShowsClearButton:(BOOL)showsClearButton animated:(BOOL)animated
{
  _showsClearButton = showsClearButton;
  if (showsClearButton) {
    self.clearButton.hidden = NO;
  } else {
    self.clearButton.hidden = YES;
  }
}


- (IBAction)clearButtonClicked:(id)sender {
  [self.delegate searchBarClearButtonClicked:self];
}

- (IBAction)cancelButtonClicked:(id)sender {
  [self.textField resignFirstResponder];
  if (![self.text isEqualToString:self.textBeforeLastEdit]) {
    self.text = self.textBeforeLastEdit;
    [self.delegate searchBar:self textDidChange:self.text];
  }
  [self.delegate searchBarCancelButtonClicked:self];
}

- (IBAction)searchBarTapped:(id)sender {
  [self.textField becomeFirstResponder];
}

#pragma mark - Internal View Delegates
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  self.textBeforeLastEdit = self.text;
  if ([self.text isEqualToString:self.defaultQuery]) self.text = @"";
  [self.delegate searchBarTextDidBeginEditing:self];
}

- (void)textChanged:(id)sender
{
  [self.delegate searchBar:self textDidChange:self.text];
}

- (void)textFieldSearchButtonClicked:(id)sender
{
  DDLogVerbose(@"serach button clicked");
  [self.delegate searchBarSearchButtonClicked:self];
}



@end
