//
//  DFPeoplePickerSecondaryAction.h
//  Strand
//
//  Created by Henry Bridge on 1/22/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutContact.h"

@interface DFPeoplePickerSecondaryAction : NSObject

typedef void (^DFPeoplePickerSecondaryActionHandler)(DFPeanutContact *contact);
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, retain) UIColor *foregroundColor;
@property (nonatomic, retain) NSString *buttonText;
@property (nonatomic, retain) UIImage *buttonImage;
@property (nonatomic, copy) DFPeoplePickerSecondaryActionHandler actionHandler;

@end
