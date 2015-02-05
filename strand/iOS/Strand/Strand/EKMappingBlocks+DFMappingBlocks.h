//
//  EKMappingBlocks+DFMappingBlocks.h
//  Strand
//
//  Created by Derek Parham on 2/4/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EKMappingBlocks.h>

@interface EKMappingBlocks (DFMappingBlocks)

+(EKMappingValueBlock)dateMappingBlock;

+(EKMappingReverseBlock)dateReverseMappingBlock;


@end
