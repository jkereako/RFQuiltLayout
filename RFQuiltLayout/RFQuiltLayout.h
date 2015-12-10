//
//  RFQuiltLayout.h
//  
//  Created by Bryce Redd on 12/7/12.
//  Copyright (c) 2012. All rights reserved.
//

@import UIKit;

@protocol RFQuiltLayoutDelegate <UICollectionViewDelegate>

@optional

// Defaults to 1x1
- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
// defaults to uiedgeinsetszero
- (UIEdgeInsets)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)layout insetsForItemAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface RFQuiltLayout : UICollectionViewLayout

@property (nonatomic, weak) IBOutlet NSObject<RFQuiltLayoutDelegate>* delegate;

@property (nonatomic) CGSize cellSize; // defaults to 100x100
@property (nonatomic) UICollectionViewScrollDirection scrollDirection; // defaults to vertical

// Set this only if you have fewer than 1,000 items. This provides the correct size from the start
// and improves scrolling speed at the cost of extra loading time in the beginning.
@property (nonatomic, getter=shouldPreemptivelyRenderLayout) BOOL preemptivelyRenderLayout;

@end
