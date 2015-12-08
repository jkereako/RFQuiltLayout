//
//  RFViewController.m
//  QuiltDemo
//
//  Created by Bryce Redd on 12/26/12.
//  Copyright (c) 2012 Bryce Redd. All rights reserved.
//

#import "RFViewController.h"
#import "RFViewModel.h"
#import <QuartzCore/QuartzCore.h>

@interface RFViewController () <UICollectionViewDelegate> {
  BOOL isAnimating;
}

@property (nonatomic) RFViewModel *viewModel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@end

int num = 0;

@implementation RFViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.viewModel = [RFViewModel new];

  [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];

  RFQuiltLayout* layout = (id)[self.collectionView collectionViewLayout];
  layout.direction = UICollectionViewScrollDirectionVertical;
  layout.blockPixels = CGSizeMake(75,75);

  [self.collectionView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  [self.collectionView reloadData];
}

- (IBAction)remove:(id)sender {

  if (!self.viewModel.numbers.count) {
    return;
  }

  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
  NSIndexPath *toRemove = [visibleIndexPaths objectAtIndex:(arc4random() % visibleIndexPaths.count)];
  [self removeIndexPath:toRemove];
}

- (IBAction)refresh:(id)sender {
  self.viewModel = nil;
  self.viewModel = [RFViewModel new];

  [self.collectionView reloadData];
}

- (IBAction)add:(id)sender {
  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
  if (visibleIndexPaths.count == 0) {
    [self addIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    return;
  }
  NSUInteger middle = (NSUInteger)floor(visibleIndexPaths.count / 2);
  NSIndexPath *toAdd = [visibleIndexPaths firstObject];[visibleIndexPaths objectAtIndex:middle];
  [self addIndexPath:toAdd];

}

#pragma mark - UICollectionView Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  [self removeIndexPath:indexPath];
}

#pragma mark - Helper methods

- (void)addIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row > self.viewModel.numbers.count) {
    return;
  }

  if(isAnimating) return;
  isAnimating = YES;

  RFViewController __weak * weakSelf = self;
  [self.collectionView performBatchUpdates:^{
    NSInteger index = indexPath.row;
    [weakSelf.numbers insertObject:@(++num) atIndex: (NSUInteger)index];
    [weakSelf.numberWidths insertObject:@(1 + arc4random() % 3) atIndex: (NSUInteger)index];
    [weakSelf.numberHeights insertObject:@(1 + arc4random() % 3) atIndex: (NSUInteger)index];
    [weakSelf.collectionView insertItemsAtIndexPaths:@[[NSIndexPath
                                                        indexPathForRow: (NSInteger)index
                                                        inSection:0]]];
  } completion:^(BOOL done) {
    isAnimating = NO;
  }];
}

- (void)removeIndexPath:(NSIndexPath *)indexPath {
  if(!self.numbers.count || indexPath.row > self.numbers.count) return;

  if(isAnimating) return;
  isAnimating = YES;

  RFViewController __weak * weakSelf = self;
  [self.collectionView performBatchUpdates:^{
    NSInteger index = indexPath.row;
    [weakSelf.numbers removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.numberWidths removeObjectAtIndex: (NSUInteger)index];
    [weakSelf.numberHeights removeObjectAtIndex: (NSUInteger)index];
    [weakSelf.collectionView deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForRow: (NSInteger)index inSection:0]]];
  } completion:^(BOOL done) {
    isAnimating = NO;
  }];
}

@end
