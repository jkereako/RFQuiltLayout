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

@interface RFViewController () <UICollectionViewDelegate>

@property (nonatomic, readwrite, weak) IBOutlet RFViewModel *viewModel;
@property (nonatomic, readwrite, weak) IBOutlet UICollectionView *collectionView;

@property (nonatomic, readwrite, getter=isAnimating) BOOL animating;

- (IBAction)add:(UIBarButtonItem *)sender;
- (IBAction)remove:(UIBarButtonItem *)sender;
- (IBAction)refresh:(UIBarButtonItem *)sender;

@end

@implementation RFViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [self.collectionView registerClass:[UICollectionViewCell class]
          forCellWithReuseIdentifier:@"cell"];

  RFQuiltLayout* layout = (id)[self.collectionView collectionViewLayout];
  layout.direction = UICollectionViewScrollDirectionVertical;
  layout.blockPixels = CGSizeMake(75,75);

  [self.collectionView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [self.collectionView reloadData];
}

#pragma mark - Actions
- (IBAction)add:(UIBarButtonItem * __unused)sender {
  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];

  if (!visibleIndexPaths.count) {
    [self addIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];

    return;
  }

  [self addIndexPath:visibleIndexPaths[0]];

}

- (IBAction)remove:(UIBarButtonItem * __unused)sender {

  if (!self.viewModel.numbers.count) {
    return;
  }

  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
  NSIndexPath *toRemove = [visibleIndexPaths objectAtIndex:(arc4random() % visibleIndexPaths.count)];

  [self removeIndexPath:toRemove];
}

- (IBAction)refresh:(UIBarButtonItem * __unused)sender {
  [self.viewModel refreshData];
  [self.collectionView reloadData];
}

#pragma mark - UICollectionView Delegate
- (void)collectionView:(UICollectionView * __unused)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  [self removeIndexPath:indexPath];
}

#pragma mark - Helper methods
- (void)addIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row > self.viewModel.numbers.count) {
    return;
  }

  if(self.isAnimating) {
    return;
  }

  self.animating = YES;
  RFViewController * __weak weakSelf = self;

  [self.collectionView performBatchUpdates:^(void) {
    NSInteger index = indexPath.row;

    [weakSelf.viewModel.numbers insertObject:@(weakSelf.viewModel.numbers.count + 1)
                                     atIndex: (NSUInteger)index];

    [weakSelf.viewModel.numberWidths insertObject:@(1 + arc4random() % 3)
                                          atIndex: (NSUInteger)index];

    [weakSelf.viewModel.numberHeights insertObject:@(1 + arc4random() % 3)
                                           atIndex: (NSUInteger)index];

    [weakSelf.collectionView
     insertItemsAtIndexPaths:@[[NSIndexPath indexPathForRow: (NSInteger)index inSection: 0]]
     ];
  }
                                completion:^(BOOL done __unused) {
                                  self.animating = NO;
                                }
   ];
}

- (void)removeIndexPath:(NSIndexPath *)indexPath {
  if(!self.viewModel.numbers.count ||
     indexPath.row > self.viewModel.numbers.count ||
     self.isAnimating) {
    return;
  }

  self.animating = YES;
  RFViewController * __weak weakSelf = self;

  [self.collectionView performBatchUpdates:^{
    NSInteger index = indexPath.row;
    [weakSelf.viewModel.numbers removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.viewModel.numberWidths removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.viewModel.numberHeights removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.collectionView
     deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]
     ];
  }
                                completion:^(BOOL done __unused) {
                                  weakSelf.animating = NO;
                                }];
}

@end
