//
//  RFViewModel.m
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

#import "RFViewModel.h"

@interface RFViewModel ()

@property (nonatomic) NSMutableArray *numbers;
@property (nonatomic) NSMutableArray *cellWidths;
@property (nonatomic) NSMutableArray *cellHeights;
@property (nonatomic, readonly) NSUInteger randomInteger;

@end

@implementation RFViewModel

- (instancetype)init {
  self = [super init];

  if (self) {
    [self refreshData];
  }

  return self;
}

- (void)refreshData {
  // Reset the properties
  self.numbers = @[].mutableCopy;
  self.cellWidths = @[].mutableCopy;
  self.cellHeights = @[].mutableCopy;

  // Assign new values
  for(NSUInteger i = 0; i < 15; i ++) {
    [self.numbers addObject:@(i)];
    [self.cellWidths addObject:@(self.randomInteger)];
    [self.cellHeights addObject:@(self.randomInteger)];
  }
}

- (void)collectionView:(UICollectionView *)cv
          addIndexPath:(NSIndexPath *)indexPath
       completionBlock:(void(^)(void))block {
  // Check for nil
  NSParameterAssert(cv);
  NSParameterAssert(indexPath);

  if (indexPath.row > self.numbers.count) {
    return;
  }

  RFViewModel * __weak weakSelf = self;

  [cv performBatchUpdates:^(void) {
    NSInteger index = indexPath.row;

    [weakSelf.numbers insertObject:@(weakSelf.numbers.count + 1)
                           atIndex: (NSUInteger)index];

    [weakSelf.cellWidths insertObject:@(weakSelf.randomInteger)
                                atIndex: (NSUInteger)index];

    [weakSelf.cellHeights insertObject:@(weakSelf.randomInteger)
                                 atIndex: (NSUInteger)index];

    [cv insertItemsAtIndexPaths:@[[NSIndexPath indexPathForRow: (NSInteger)index inSection: 0]]];
  }
               completion:^(BOOL done __unused) {
                 block();
               }
   ];
}

- (void)collectionView:(UICollectionView *)cv
       removeIndexPath:(NSIndexPath *)indexPath
       completionBlock:(void(^)(void))block {
  // Check for nil
  NSParameterAssert(cv);
  NSParameterAssert(indexPath);

  if(!self.numbers.count || indexPath.row > self.numbers.count) {
    return;
  }

  RFViewModel * __weak weakSelf = self;

  [cv performBatchUpdates:^{
    NSInteger index = indexPath.row;
    [weakSelf.numbers removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.cellWidths removeObjectAtIndex:(NSUInteger)index];
    [weakSelf.cellHeights removeObjectAtIndex:(NSUInteger)index];
    [cv deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]];
  }
               completion:^(BOOL done __unused) {
                 block();
               }];
}

#pragma mark - Getters
- (NSUInteger)randomInteger {
  // always returns a random length between 1 and 3, weighted towards lower numbers.
  NSUInteger random = arc4random() % 6;

  switch (random) {
    case 0:
    case 1:
    case 2:
      return 1;

    case 5:
      return 3;

    default:
      return 2;
  }
}

#pragma mark - Collection view data source
- (NSInteger)collectionView:(UICollectionView * __unused)view
     numberOfItemsInSection:(NSInteger __unused)section {

  return (NSInteger)self.numbers.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

  UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"cell"
                                                             forIndexPath:indexPath];

  // Delegate the cell configuration to the view controller.
  if ([(id)self.delegate respondsToSelector:@selector(configureCell:withObject:)]) {
    [self.delegate configureCell:cell withObject:self.numbers[(NSUInteger)indexPath.row]];
  }

  return cell;
}

#pragma mark - RFQuiltLayoutDelegate
-(CGSize)collectionView:(UICollectionView * __unused)cv
                 layout:(UICollectionViewLayout * __unused)layout
 sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  
  NSAssert(indexPath.row <= self.numbers.count, @"\n\n  ERROR: Requested non-existant cell.");

  CGFloat width = [self.cellWidths[(NSUInteger)indexPath.row] floatValue];
  CGFloat height = [self.cellHeights[(NSUInteger)indexPath.row] floatValue];

  return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView * __unused)cv
                        layout:(UICollectionViewLayout * __unused)layout
      insetsForItemAtIndexPath:(NSIndexPath * __unused)indexPath {

  return UIEdgeInsetsMake(1.0f, 1.0f, 1.0f, 1.0f);
}

@end
