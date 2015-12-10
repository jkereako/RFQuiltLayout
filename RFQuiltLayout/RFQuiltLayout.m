//
//  RFQuiltLayout.h
//
//  Created by Bryce Redd on 12/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "RFQuiltLayout.h"

@interface RFQuiltLayout ()

@property(nonatomic) CGPoint firstOpenSpace;
@property(nonatomic) CGPoint furthestBlockCoordinate;

// this will be a 2x2 dictionary storing nsindexpaths
// which indicate the available/filled spaces in our quilt
@property(nonatomic) NSMutableDictionary *indexPathByPosition;

// indexed by "section, row" this will serve as the rapid
// lookup of block position by indexpath.
@property(nonatomic) NSMutableDictionary *positionByIndexPath;

// previous layout cache.  this is to prevent choppiness
// when we scroll to the bottom of the screen - uicollectionview
// will repeatedly call layoutattributesforelementinrect on
// each scroll event.  pow!
@property(nonatomic) NSArray *layoutAttributesCache;
@property(nonatomic) CGRect layoutRectCache;
// remember the last indexpath placed, as to not
// relayout the same indexpaths while scrolling
@property(nonatomic) NSIndexPath *indexPathCache;

@property(nonatomic, readonly) NSUInteger maximumNumberOfItemsInBounds;

- (void)initialize;
- (void)fillInBlocksToIndexPath:(NSIndexPath *)indexPath;
- (BOOL)insertCellAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)traverseCellsBetweenRows:(NSUInteger)start and:(NSUInteger)end
                                         block:(BOOL(^)(CGPoint))block;
- (BOOL)traverseCellsForCoordinate:(CGPoint)point withSize:(CGSize)size iterator:(BOOL(^)(CGPoint))block;
- (BOOL)traverseOpenCells:(BOOL(^)(CGPoint))block;
- (void)clearPositions;
- (NSIndexPath *)indexPathForCoordinate:(CGPoint)coordinate;
- (CGPoint)coordinateForIndexPath:(NSIndexPath *)path;
- (void)setCoordinate:(CGPoint)point forIndexPath:(NSIndexPath *)indexPath;
- (void)fillInBlocksToUnboundRow:(NSUInteger)endRow;
- (CGSize)sizeForCellAtIndexPath:(NSIndexPath *)indexPath;
- (CGRect)rectForIndexPath:(NSIndexPath *)path;

@end

@implementation RFQuiltLayout

- (instancetype)init {
  self = [super init];

  if (self) {
    [self initialize];
  }

  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];

  if (self) {
    [self initialize];
  }

  return self;
}

- (void)initialize {
  // defaults
  self.direction = UICollectionViewScrollDirectionVertical;
  self.cellSize = CGSizeMake(100.f, 100.f);
  self.preemptivelyRenderLayout = NO;
}

#pragma mark - Overridden methods
- (CGSize)collectionViewContentSize {
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      return CGSizeMake(CGRectGetWidth(contentRect),
                        (self.furthestBlockCoordinate.y + 1) * self.cellSize.height);

    case UICollectionViewScrollDirectionHorizontal:
      return CGSizeMake((self.furthestBlockCoordinate.x + 1) * self.cellSize.width,
                        CGRectGetHeight(contentRect));
  }
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
  if (!self.delegate) {
    @throw([NSException exceptionWithName:@"NotFound" reason:@"Delegate not set" userInfo:nil]);
  }

  // Check if the supplied rect is identical to the cached rect
  if(CGRectEqualToRect(rect, self.layoutRectCache)) {
    return self.layoutAttributesCache;
  }

  // Cache the rect
  self.layoutRectCache = rect;

  // "Unbound" means, for example, the number of rows in a vertically scrolling view
  NSUInteger unboundStart = 0;
  NSUInteger unboundLength = 0;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unboundStart = (NSUInteger)(rect.origin.y / self.cellSize.height);
      unboundLength = (NSUInteger)(rect.size.height / self.cellSize.height);
      break;

    default:
      unboundStart = (NSUInteger)(rect.origin.x / self.cellSize.width);
      unboundLength = (NSUInteger)((rect.size.width / self.cellSize.width) + 1);
      break;
  }

  NSUInteger unboundEnd = unboundStart + unboundLength;

  if (self.shouldPreemptivelyRenderLayout) {
    [self fillInBlocksToUnboundRow:INT_MAX];
  }

  else {
    [self fillInBlocksToUnboundRow:unboundEnd];
  }

  RFQuiltLayout * __weak weakSelf = self;

  // find the indexPaths between those rows
  NSMutableSet *attributes = [NSMutableSet set];
  [self traverseCellsBetweenRows:unboundStart
                                              and:unboundEnd
                                         block:^(CGPoint point) {
                                           NSIndexPath* indexPath;
                                           indexPath = [weakSelf indexPathForCoordinate:point];

                                           if(indexPath) {
                                             [attributes addObject:[weakSelf layoutAttributesForItemAtIndexPath:indexPath]];
                                           }

                                           return YES;
                                         }];

  // Cache the layout attributes
  return (self.layoutAttributesCache = [attributes allObjects]);
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
  UIEdgeInsets insets = UIEdgeInsetsZero;
  CGRect frame = CGRectZero;
  UICollectionViewLayoutAttributes *attributes;

  if([self.delegate respondsToSelector:@selector(collectionView:layout:insetsForItemAtIndexPath:)]) {
    insets = [self.delegate collectionView:self.collectionView
                                    layout:self insetsForItemAtIndexPath:indexPath];
  }

  frame = [self rectForIndexPath:indexPath];
  attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
  attributes.frame = UIEdgeInsetsInsetRect(frame, insets);

  return attributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
  return !(CGSizeEqualToSize(newBounds.size, self.collectionView.frame.size));
}

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems {
  [super prepareForCollectionViewUpdates:updateItems];

  for(UICollectionViewUpdateItem *item in updateItems) {
    switch (item.updateAction) {
      case UICollectionUpdateActionInsert:
      case UICollectionUpdateActionMove:
        [self fillInBlocksToIndexPath:item.indexPathAfterUpdate];
        break;

      default:
        break;
    }
  }
}

- (void)invalidateLayout {
  [super invalidateLayout];

  _furthestBlockCoordinate = CGPointZero;
  self.firstOpenSpace = CGPointZero;
  self.layoutRectCache = CGRectZero;
  self.layoutAttributesCache = nil;
  self.indexPathCache = nil;

  [self clearPositions];
}

- (void)prepareLayout {
  [super prepareLayout];

  if (!self.delegate) {
    @throw([NSException exceptionWithName:@"NotFound" reason:@"Delegate not set" userInfo:nil]);
  }

  NSUInteger unbound = 0;
  CGRect scrollFrame = CGRectMake(self.collectionView.contentOffset.x,
                                  self.collectionView.contentOffset.y,
                                  self.collectionView.frame.size.width,
                                  self.collectionView.frame.size.height);
  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unbound = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.height) + 1;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unbound = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.width) + 1;
      break;
  }

  if (self.shouldPreemptivelyRenderLayout) {
    [self fillInBlocksToUnboundRow:INT_MAX];
  }

  else {
    [self fillInBlocksToUnboundRow:unbound];
  }
}


#pragma mark - Getters
/**
 Calculates the maximum number of items which can fit in a row inside the collection view. This
 provides an upper bound for the layout.

 @returns Returns the maximum number of cells which can fit in the collection view for any row.
 */
- (NSUInteger)maximumNumberOfItemsInBounds {
  NSUInteger size = 0;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      size = (NSUInteger)(CGRectGetWidth(contentRect) / self.cellSize.width);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      size = (NSUInteger)(CGRectGetHeight(contentRect) / self.cellSize.height);
  }

  if(size == 0) {
    NSLog(@"Cannot fit block of size: %@ in content rect %@!  Defaulting to 1",
          NSStringFromCGSize(self.cellSize), NSStringFromCGRect(contentRect));
    return 1;
  }

  return size;
}

#pragma mark - Setters
- (void)setDirection:(UICollectionViewScrollDirection)direction {
  _direction = direction;

  [self invalidateLayout];
}

- (void)setCellSize:(CGSize)size {
  _cellSize = size;

  [self invalidateLayout];
}

- (void) setFurthestBlockCoordinate:(CGPoint)point {
  _furthestBlockCoordinate = CGPointMake(MAX(_furthestBlockCoordinate.x, point.x),
                                         MAX(_furthestBlockCoordinate.y, point.y)
                                         );
}

#pragma mark - Private methods
- (void)fillInBlocksToUnboundRow:(NSUInteger)endRow {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger sectionCount = [self.collectionView numberOfSections];

  for (NSInteger section = self.indexPathCache.section; section < sectionCount; section++) {
    NSInteger rowCount = [self.collectionView numberOfItemsInSection:section];

    for (NSInteger row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1); row < rowCount; row++) {
      NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self insertCellAtIndexPath:indexPath]) {
        self.indexPathCache = indexPath;
      }

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          if (self.firstOpenSpace.y >= endRow) {
            return;
          }
          break;

        case UICollectionViewScrollDirectionHorizontal:
          if (self.firstOpenSpace.x >= endRow) {
            return;
          }

          break;
      }
    }
  }
}

- (void)fillInBlocksToIndexPath:(NSIndexPath *)indexPath {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger sectionCount = [self.collectionView numberOfSections];

  // Iterate over the sections
  for (NSInteger section = self.indexPathCache.section; section < sectionCount; section++) {
    NSInteger rowCount = [self.collectionView numberOfItemsInSection:section];

    // Iterate over the rows
    for (NSInteger row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1); row < rowCount; row++) {

      // exit when we are past the desired row
      if(section >= indexPath.section && row > indexPath.row) {
        return;
      }

      NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self insertCellAtIndexPath:newIndexPath]) {
        self.indexPathCache = newIndexPath;
      }
    }
  }
}

- (BOOL)insertCellAtIndexPath:(NSIndexPath *)indexPath {
  CGSize cellSize = [self sizeForCellAtIndexPath:indexPath];
  BOOL vert = self.direction == UICollectionViewScrollDirectionVertical;

  RFQuiltLayout * __weak weakSelf = self;

  return ![self traverseOpenCells:^(CGPoint blockOrigin) {

    // we need to make sure each square in the desired
    // area is available before we can place the square

    BOOL didTraverseAllBlocks = [self traverseCellsForCoordinate:blockOrigin
                                                        withSize:cellSize
                                                        iterator:^(CGPoint point) {
                                                          BOOL hasSpaceAvailable = (BOOL)![self indexPathForCoordinate:point];
                                                          BOOL isInBounds = NO;
                                                          BOOL hasMaximumBoundSize = NO;

                                                          switch (weakSelf.direction) {
                                                            case UICollectionViewScrollDirectionVertical:
                                                              isInBounds = (point.x < weakSelf.maximumNumberOfItemsInBounds);
                                                              hasMaximumBoundSize = (blockOrigin.x == 0);
                                                              break;
                                                              
                                                            case UICollectionViewScrollDirectionHorizontal:
                                                              isInBounds = (point.y < weakSelf.maximumNumberOfItemsInBounds);
                                                              hasMaximumBoundSize = (blockOrigin.y == 0);
                                                              break;
                                                          }

//                                                          if (hasSpaceAvailable && hasMaximumBoundSize && !isInBounds) {
//                                                            NSLog(@"Item will not fit within bounds. Adding anyway.");
//                                                            return YES;
//                                                          }

                                                          return (BOOL)(hasSpaceAvailable && isInBounds);
                                                        }];


    if (!didTraverseAllBlocks) {
      return YES;
    }

    // because we have determined that the space is all
    // available, lets fill it in as taken.

    [self setIndexPath:indexPath forPosition:blockOrigin];

    [self traverseCellsForCoordinate:blockOrigin
                            withSize:cellSize
                            iterator:^(CGPoint point) {
                              [self setCoordinate:point forIndexPath:indexPath];

                              self.furthestBlockCoordinate = point;

                              return YES;
                            }];

    return NO;
  }];
}

// returning no in the callback will
// terminate the iterations early
- (BOOL)traverseCellsBetweenRows:(NSUInteger)start and:(NSUInteger)end block:(BOOL(^)(CGPoint))block {
  for(NSUInteger unbound = start; unbound < end; unbound++) {
    for(NSUInteger bounds = 0; bounds < self.maximumNumberOfItemsInBounds; bounds++) {

      CGPoint point = CGPointZero;

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(bounds, unbound);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unbound, bounds);
          break;
      }

      if(!block(point)) {
        return NO;
      }
    }
  }

  return YES;
}

- (BOOL)traverseCellsForCoordinate:(CGPoint)point
                          withSize:(CGSize)size
                          iterator:(BOOL(^)(CGPoint))block {
  for(NSUInteger column = (NSUInteger)point.x; column < point.x + size.width; column++) {
    for (NSUInteger row = (NSUInteger)point.y; row < point.y + size.height; row++) {

      if(!block(CGPointMake(column, row))) {
        // Terminate iteration
        return NO;
      }
    }
  }
  return YES;
}

// returning no in the callback will
// terminate the iterations early
- (BOOL)traverseOpenCells:(BOOL(^)(CGPoint))block {
  BOOL allTakenBefore = YES;
  NSUInteger unbound = 0;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unbound = (NSUInteger)self.firstOpenSpace.y;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unbound = (NSUInteger)self.firstOpenSpace.x;
      break;
  }

  do {
    for(NSUInteger bounds = 0; bounds < self.maximumNumberOfItemsInBounds; bounds++) {

      CGPoint point = CGPointZero;

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(bounds, unbound);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unbound, bounds);
          break;
      }

      if([self indexPathForCoordinate:point]) {
        continue;
      }

      if(allTakenBefore) {
        self.firstOpenSpace = point;
        allTakenBefore = NO;
      }

      if(!block(point)) {
        return NO;
      }
    }

    unbound++;
  } while (unbound);

  NSAssert(0, @"Unable to find a insertion point for a cell.");

  return YES;
}

- (void)clearPositions {
  self.indexPathByPosition = [NSMutableDictionary dictionary];
  self.positionByIndexPath = [NSMutableDictionary dictionary];
}

- (NSIndexPath*)indexPathForCoordinate:(CGPoint)coordinate {
  NSNumber *unboundPoint, *boundPoint;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unboundPoint = @(coordinate.y);
      boundPoint = @(coordinate.x);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unboundPoint = @(coordinate.x);
      boundPoint = @(coordinate.y);
      break;
  }

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  return self.indexPathByPosition[boundPoint][unboundPoint];
}

- (void)setCoordinate:(CGPoint)point forIndexPath:(NSIndexPath*)indexPath {

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  NSNumber *unboundPoint, *boundPoint;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unboundPoint = @(point.y);
      boundPoint = @(point.x);
      break;

    default:
      unboundPoint = @(point.x);
      boundPoint = @(point.y);
      break;
  }

  NSMutableDictionary* innerDict = self.indexPathByPosition[boundPoint];

  if (!innerDict) {
    self.indexPathByPosition[boundPoint] = [NSMutableDictionary dictionary];
  }

  self.indexPathByPosition[boundPoint][unboundPoint] = indexPath;
}

- (void)setIndexPath:(NSIndexPath *)path forPosition:(CGPoint)point {
  NSMutableDictionary* innerDict = self.positionByIndexPath[@(path.section)];

  if (!innerDict) {
    self.positionByIndexPath[@(path.section)] = [NSMutableDictionary dictionary];
  }

  self.positionByIndexPath[@(path.section)][@(path.row)] = [NSValue valueWithCGPoint:point];
}

- (CGPoint)coordinateForIndexPath:(NSIndexPath *)path {
  // if item does not have a position, we will make one!
  if(!self.positionByIndexPath[@(path.section)][@(path.row)]) {
    [self fillInBlocksToIndexPath:path];
  }

  return [self.positionByIndexPath[@(path.section)][@(path.row)] CGPointValue];
}


- (CGRect)rectForIndexPath:(NSIndexPath *)path {
  CGPoint position = [self coordinateForIndexPath:path];
  CGSize elementSize = [self sizeForCellAtIndexPath:path];
  CGFloat padding = 0.0;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical: {

      padding = (CGRectGetWidth(contentRect) - self.maximumNumberOfItemsInBounds * self.cellSize.width) / 2;
      return CGRectMake(position.x * self.cellSize.width + padding,
                        position.y * self.cellSize.height,
                        elementSize.width * self.cellSize.width,
                        elementSize.height * self.cellSize.height);

    }

    case UICollectionViewScrollDirectionHorizontal: {
      padding = (CGRectGetHeight(contentRect) - self.maximumNumberOfItemsInBounds * self.cellSize.height) / 2;
      return CGRectMake(position.x * self.cellSize.width,
                        position.y * self.cellSize.height + padding,
                        elementSize.width * self.cellSize.width,
                        elementSize.height * self.cellSize.height);
      
    }
  }
}


/**
 Defines the size for an item at a particular index path. Implement this to dynamically size cells
 at run-time.
 */
- (CGSize)sizeForCellAtIndexPath:(NSIndexPath *)indexPath {
  // The default size is 1x1
  CGSize size = CGSizeMake(1, 1);
  
  if([self.delegate
      respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)]
     ) {
    size = [self.delegate collectionView:[self collectionView]
                                  layout:self sizeForItemAtIndexPath:indexPath];
  }
  
  return size;
}

@end
