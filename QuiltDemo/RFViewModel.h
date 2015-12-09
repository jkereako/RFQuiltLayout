//
//  RFViewModel.h
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RFQuiltLayout.h"

@class RFViewController;

@interface RFViewModel : NSObject <UICollectionViewDataSource, RFQuiltLayoutDelegate>

@property (nonatomic) NSMutableArray* numbers;
@property (nonatomic) NSMutableArray* numberWidths;
@property (nonatomic) NSMutableArray* numberHeights;

- (void)refreshData;

@end
