//
//  DFPeoplePickerNoResultsDescriptor.h
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFPeoplePickerNoResultsDescriptor : NSObject

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *buttonTitle;
@property (nonatomic, copy) DFVoidBlock buttonHandler;

+ (DFPeoplePickerNoResultsDescriptor *)descriptorWithTitle:(NSString *)title
                                               buttonTitle:(NSString *)buttonTitle
                                             buttonHandler:(DFVoidBlock)buttonHandler;

@end
