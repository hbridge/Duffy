//
//  DFSearchResultTableViewCell.h
//  Duffy
//
//  Created by Henry Bridge on 5/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSearchResultTableViewCell : UITableViewCell
@property (readonly, weak, nonatomic) IBOutlet UILabel *textLabel;
@property (readonly, weak, nonatomic) IBOutlet UILabel *detailTextLabel;

@end
