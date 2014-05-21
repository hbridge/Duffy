//
//  DFSearchBar.h
//  Duffy
//
//  Created by Henry Bridge on 5/21/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DFSearchBarDelegate;


@interface DFSearchBar : UIView <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (nonatomic) BOOL showsCancelButton;
@property (nonatomic) BOOL showsClearButton;

@property (strong, nonatomic) NSString *defaultQuery;
@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSString *textBeforeLastEdit;
@property (strong, nonatomic) NSString *placeholder;

@property (weak, nonatomic) id<DFSearchBarDelegate> delegate;

- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated;
- (void)setShowsClearButton:(BOOL)showsCancelButton animated:(BOOL)animated;

- (IBAction)clearButtonClicked:(id)sender;
- (IBAction)cancelButtonClicked:(id)sender;


@end

@protocol DFSearchBarDelegate <NSObject>

- (void)searchBarClearButtonClicked:(DFSearchBar *)searchBar;
- (void)searchBarCancelButtonClicked:(DFSearchBar *)searchBar;
- (void)searchBarSearchButtonClicked:(DFSearchBar *)searchBar;
- (void)searchBarTextDidBeginEditing:(DFSearchBar *)searchBar;
- (void)searchBar:(DFSearchBar *)searchBar textDidChange:(NSString *)newSearchText;

@end