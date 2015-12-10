//
//  RFViewModel.h
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

@import Foundation;
#import "RFQuiltLayout.h"

// The purpose of this protocol is to delegate the cell configuration to the controller. It may seem
// like overkill for a demo project, but this is the correct way to handle cell configuration. You
// ought to copy this behavior in your project.
@protocol RFCollectionViewControllerDelegate

@optional

- (void)configureCell:(UICollectionViewCell *)cell withObject:(id)object;
- (UIEdgeInsets)configureMargins;

@end

@interface RFViewModel : NSObject <UICollectionViewDataSource, RFQuiltLayoutDelegate>

@property (nonatomic, weak) id<RFCollectionViewControllerDelegate> delegate;

- (void)collectionView:(UICollectionView *)cv addIndexPath:(NSIndexPath *)indexPath completionBlock:(void(^)(void))block;
- (void)collectionView:(UICollectionView *)cv removeIndexPath:(NSIndexPath *)indexPath completionBlock:(void(^)(void))block;
- (void)refreshData;

@end
