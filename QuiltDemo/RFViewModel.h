//
//  RFViewModel.h
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

@import Foundation;
#import "RFQuiltLayout.h"

@interface RFViewModel : NSObject <UICollectionViewDataSource, RFQuiltLayoutDelegate>

- (void)collectionView:(UICollectionView *)cv addIndexPath:(NSIndexPath *)indexPath completionBlock:(void(^)(void))block;
- (void)collectionView:(UICollectionView *)cv removeIndexPath:(NSIndexPath *)indexPath completionBlock:(void(^)(void))block;
- (void)refreshData;

@end
