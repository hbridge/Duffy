//
//  DFPeoplePickerNoResultsDescriptor.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerNoResultsDescriptor.h"

@implementation DFPeoplePickerNoResultsDescriptor

+ (DFPeoplePickerNoResultsDescriptor *)descriptorWithTitle:(NSString *)title
                                               buttonTitle:(NSString *)buttonTitle
                                             buttonHandler:(DFVoidBlock)buttonHandler
{
  DFPeoplePickerNoResultsDescriptor *descriptor = [[DFPeoplePickerNoResultsDescriptor alloc] init];
  descriptor.title = title;
  descriptor.buttonTitle = buttonTitle;
  descriptor.buttonHandler = buttonHandler;
  return descriptor;
}

@end
