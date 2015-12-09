//
//  RFViewModel.m
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

#import "RFViewModel.h"
#import "RFViewController.h"

@interface RFViewModel ()

- (UIColor *)colorForNumber:(NSNumber *)number;
- (NSUInteger)randomLength;

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
  NSMutableArray *someNumbers = [@[] mutableCopy];
  NSMutableArray *someNumberWidths = @[].mutableCopy;
  NSMutableArray *someNumberHeights = @[].mutableCopy;

  for(NSUInteger i = 0; i < 15; i ++) {
    [someNumbers addObject:@(i)];
    [someNumberWidths addObject:@([self randomLength])];
    [someNumberHeights addObject:@([self randomLength])];
  }

  self.numbers = someNumbers;
  self.numberWidths = someNumberWidths;
  self.numberHeights = someNumberHeights;

}

#pragma mark - Collection view data source
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
  return (NSInteger)self.numbers.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"cell"
                                                             forIndexPath:indexPath];
  cell.backgroundColor = [self colorForNumber: self.numbers[(NSUInteger)indexPath.row]];

  UILabel* label = (id)[cell viewWithTag:5];

  if(!label) {
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
  }

  label.tag = 5;
  label.textColor = [UIColor blackColor];
  label.text = [NSString stringWithFormat:@"%@", self.numbers[(NSUInteger)indexPath.row]];
  label.backgroundColor = [UIColor clearColor];
  [cell addSubview:label];

  return cell;
}

#pragma mark – RFQuiltLayoutDelegate

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout blockSizeForItemAtIndexPath:(NSIndexPath *)indexPath{

  if(indexPath.row >= self.numbers.count) {
    NSLog(@"Asking for index paths of non-existant cells!! %ld from %lu cells", (long)indexPath.row, (unsigned long)self.numbers.count);
  }

  CGFloat width = [self.numberWidths[(NSUInteger)indexPath.row] floatValue];
  CGFloat height = [self.numberHeights[(NSUInteger)indexPath.row] floatValue];

  return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetsForItemAtIndexPath:(NSIndexPath *)indexPath {
  return UIEdgeInsetsMake(2, 2, 2, 2);
}


- (UIColor *)colorForNumber:(NSNumber *)number {
  return [UIColor colorWithHue:((19 * number.intValue) % 255)/255.f
                    saturation:1.f
                    brightness:1.f
                         alpha:1.f];
}

- (NSUInteger)randomLength {
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

@end
