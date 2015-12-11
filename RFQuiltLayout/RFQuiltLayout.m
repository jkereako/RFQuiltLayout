//
//  RFQuiltLayout.h
//
//  Created by Bryce Redd on 12/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "RFQuiltLayout.h"

@interface RFQuiltLayout ()

@property(nonatomic) CGPoint firstOpenSpace;
@property(nonatomic) CGPoint furthestCellPosition;

// A 2x2 dictionary which contains `NSIndexPath` objects to indicate the available and filled cells
// in the collection view
/*
 {
 0 =     {
 0 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 3 = "<NSIndexPath: 0xc000000000200016> {length = 2, path = 0 - 1}";
 2 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 5 = "<NSIndexPath: 0xc000000000400016> {length = 2, path = 0 - 2}";
 1 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 4 = "<NSIndexPath: 0xc000000000200016> {length = 2, path = 0 - 1}";
 };
 1 =     {
 0 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 3 = "<NSIndexPath: 0xc000000000200016> {length = 2, path = 0 - 1}";
 2 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 5 = "<NSIndexPath: 0xc000000000400016> {length = 2, path = 0 - 2}";
 1 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 4 = "<NSIndexPath: 0xc000000000200016> {length = 2, path = 0 - 1}";
 };
 2 =     {
 0 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 2 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 5 = "<NSIndexPath: 0xc000000000400016> {length = 2, path = 0 - 2}";
 1 = "<NSIndexPath: 0xc000000000000016> {length = 2, path = 0 - 0}";
 };
 }

 */
@property(nonatomic) NSMutableDictionary *indexPathByPosition;

// indexed by "section, row" this will serve as the rapid lookup of block position by indexpath.
@property(nonatomic) NSMutableDictionary *positionByIndexPath;

// previous layout cache.  this is to prevent choppiness when we scroll to the bottom of the screen
// - uicollectionview will repeatedly call layoutattributesforelementinrect on each scroll event.
// pow!
@property(nonatomic) NSArray *layoutAttributesCache;
@property(nonatomic) CGRect layoutRectCache;
// remember the last indexpath placed, as to not relayout the same indexpaths while scrolling
@property(nonatomic) NSIndexPath *indexPathCache;

@property(nonatomic, readonly) NSUInteger maximumNumberOfItemsInBounds;

- (void)initialize;
- (void)clearPositions;

//-- Cell insertion
- (void)insertCellsToUnboundIndex:(NSUInteger)index;
- (void)insertCellsToIndexPath:(NSIndexPath *)indexPath;
- (BOOL)insertCellAtIndexPath:(NSIndexPath *)indexPath;

//-- Cell traversal
- (void)traverseCellsBetweenBounds:(NSUInteger)start and:(NSUInteger)end
                             block:(void(^)(CGPoint))block;
- (BOOL)traverseCellsForPosition:(CGPoint)point withSize:(CGSize)size block:(BOOL(^)(CGPoint))block;
- (BOOL)traverseOpenCells:(BOOL(^)(CGPoint))block;

//-- Getters
- (CGSize)sizeForCellAtIndexPath:(NSIndexPath *)indexPath;
- (CGRect)rectForIndexPath:(NSIndexPath *)path;
- (NSIndexPath *)indexPathForPosition:(CGPoint)position;
- (CGPoint)positionForIndexPath:(NSIndexPath *)path;

//-- Setters
- (void)setPosition:(CGPoint)point forIndexPath:(NSIndexPath *)indexPath;

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
  self.scrollDirection = UICollectionViewScrollDirectionVertical;
  self.cellSize = CGSizeMake(100.f, 100.f);
  self.preemptivelyRenderLayout = NO;
}

- (void)clearPositions {
  self.indexPathByPosition = [NSMutableDictionary dictionary];
  self.positionByIndexPath = [NSMutableDictionary dictionary];
}

#pragma mark - Overridden methods
- (CGSize)collectionViewContentSize {
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      return CGSizeMake(CGRectGetWidth(contentRect),
                        (self.furthestCellPosition.y + 1) * self.cellSize.height);

    case UICollectionViewScrollDirectionHorizontal:
      return CGSizeMake((self.furthestCellPosition.x + 1) * self.cellSize.width,
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
  NSUInteger unboundIndexStart = 0;
  NSUInteger length = 0;

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      unboundIndexStart = (NSUInteger)(rect.origin.y / self.cellSize.height);
      length = (NSUInteger)(rect.size.height / self.cellSize.height);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unboundIndexStart = (NSUInteger)(rect.origin.x / self.cellSize.width);
      length = (NSUInteger)((rect.size.width / self.cellSize.width) + 1);
      break;
  }

  NSUInteger unboundIndexEnd = unboundIndexStart + length;

  if (self.shouldPreemptivelyRenderLayout) {
    [self insertCellsToUnboundIndex:INT_MAX];
  }

  else {
    [self insertCellsToUnboundIndex:unboundIndexEnd];
  }

  RFQuiltLayout * __weak weakSelf = self;

  // find the indexPaths between those rows
  NSMutableSet *attributes = [NSMutableSet set];
  [self traverseCellsBetweenBounds:unboundIndexStart
                               and:unboundIndexEnd
                             block:^(CGPoint position) {
                               NSIndexPath *indexPath;
                               indexPath = [weakSelf indexPathForPosition:position];

                               if(indexPath) {
                                 [attributes addObject:[weakSelf layoutAttributesForItemAtIndexPath:indexPath]];
                               }
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
        [self insertCellsToIndexPath:item.indexPathAfterUpdate];
        break;

      default:
        break;
    }
  }
}

- (void)invalidateLayout {
  [super invalidateLayout];

  _furthestCellPosition = CGPointZero;
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

  NSUInteger unboundIndex = 0;
  CGRect scrollFrame = CGRectMake(self.collectionView.contentOffset.x,
                                  self.collectionView.contentOffset.y,
                                  self.collectionView.frame.size.width,
                                  self.collectionView.frame.size.height);
  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      unboundIndex = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.height) + 1;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unboundIndex = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.width) + 1;
      break;
  }

  if (self.shouldPreemptivelyRenderLayout) {
    [self insertCellsToUnboundIndex:INT_MAX];
  }

  else {
    [self insertCellsToUnboundIndex:unboundIndex];
  }
}


#pragma mark - Property getters
/**
 Calculates the maximum number of items which can fit in a row inside the collection view. This
 provides an upper bound for the layout.

 @returns Returns the maximum number of cells which can fit in the collection view for any row.
 */
- (NSUInteger)maximumNumberOfItemsInBounds {
  NSUInteger size = 0;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.scrollDirection) {
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

#pragma mark - Property setters
- (void)setScrollDirection:(UICollectionViewScrollDirection)direction {
  _scrollDirection = direction;

  [self invalidateLayout];
}

- (void)setCellSize:(CGSize)size {
  _cellSize = size;

  [self invalidateLayout];
}

- (void)setFurthestCellPosition:(CGPoint)point {
  _furthestCellPosition = CGPointMake(MAX(_furthestCellPosition.x, point.x),
                                      MAX(_furthestCellPosition.y, point.y)
                                      );
}

#pragma mark - Private methods

#pragma mark Cell insertion
- (void)insertCellsToUnboundIndex:(NSUInteger)index {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger sectionCount = [self.collectionView numberOfSections];
  NSInteger section = (!self.indexPathCache ? 0 : self.indexPathCache.section);
  NSInteger row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1);

  while (section < sectionCount) {
    NSInteger rowCount = [self.collectionView numberOfItemsInSection:section];

    while (row < rowCount) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self insertCellAtIndexPath:indexPath]) {
        self.indexPathCache = indexPath;
      }

      switch (self.scrollDirection) {
        case UICollectionViewScrollDirectionVertical:
          if (self.firstOpenSpace.y >= index) {
            return;
          }
          break;

        case UICollectionViewScrollDirectionHorizontal:
          if (self.firstOpenSpace.x >= index) {
            return;
          }

          break;
      }

      row++;
    }

    section++;
  }
}

- (void)insertCellsToIndexPath:(NSIndexPath *)indexPath {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger sectionCount = [self.collectionView numberOfSections];
  NSInteger section = 0;
  NSInteger row = 0;

  // Iterate over the sections
  for (section = self.indexPathCache.section; section < sectionCount; section++) {
    NSInteger rowCount = [self.collectionView numberOfItemsInSection:section];
    
    // Iterate over the rows
    for (row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1); row < rowCount; row++) {

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

  RFQuiltLayout * __weak weakSelf = self;

  return ![self traverseOpenCells:^(CGPoint blockOrigin) {

    // we need to make sure each square in the desired
    // area is available before we can place the square

    BOOL didTraverseAllBlocks = [self traverseCellsForPosition:blockOrigin
                                                      withSize:cellSize
                                                         block:^(CGPoint point) {
                                                           BOOL hasSpaceAvailable = (BOOL)![self indexPathForPosition:point];
                                                           BOOL isInBounds = NO;
                                                           BOOL hasMaximumBoundSize = NO;

                                                           switch (weakSelf.scrollDirection) {
                                                             case UICollectionViewScrollDirectionVertical:
                                                               isInBounds = (point.x < weakSelf.maximumNumberOfItemsInBounds);
                                                               hasMaximumBoundSize = (blockOrigin.x == 0);
                                                               break;

                                                             case UICollectionViewScrollDirectionHorizontal:
                                                               isInBounds = (point.y < weakSelf.maximumNumberOfItemsInBounds);
                                                               hasMaximumBoundSize = (blockOrigin.y == 0);
                                                               break;
                                                           }

                                                           // This condition must be handled,
                                                           // otherwise, we will have an infinite
                                                           // loop.
                                                           if (hasSpaceAvailable &&
                                                               hasMaximumBoundSize &&
                                                               !isInBounds) {
                                                             NSLog(@"View is not large enough to hold cell... inserting anyway.");
                                                             return YES;
                                                           }

                                                           return (BOOL)(hasSpaceAvailable && isInBounds);
                                                         }];


    if (!didTraverseAllBlocks) {
      return YES;
    }

    // because we have determined that the space is all
    // available, lets fill it in as taken.

    [self setIndexPath:indexPath forPosition:blockOrigin];

    [self traverseCellsForPosition:blockOrigin
                          withSize:cellSize
                             block:^(CGPoint point) {
                               [self setPosition:point forIndexPath:indexPath];

                               self.furthestCellPosition = point;

                               return YES;
                             }];

    return NO;
  }];
}

// returning no in the callback will
// terminate the iterations early
#pragma mark Cell traversal
- (void)traverseCellsBetweenBounds:(NSUInteger)start and:(NSUInteger)end block:(void(^)(CGPoint))block {
  NSUInteger unbound = 0;
  NSUInteger bounds = 0;

  for(unbound = start; unbound < end; unbound++) {
    for(bounds = 0; bounds < self.maximumNumberOfItemsInBounds; bounds++) {

      CGPoint position = CGPointZero;

      switch (self.scrollDirection) {
        case UICollectionViewScrollDirectionVertical:
          position = CGPointMake(bounds, unbound);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          position = CGPointMake(unbound, bounds);
          break;
      }

      block(position);
    }
  }
}

- (BOOL)traverseCellsForPosition:(CGPoint)point withSize:(CGSize)size block:(BOOL(^)(CGPoint))block {
  NSUInteger column = 0;
  NSUInteger row = 0;

  for(column = (NSUInteger)point.x; column < point.x + size.width; column++) {
    for (row = (NSUInteger)point.y; row < point.y + size.height; row++) {

      if(!block(CGPointMake(column, row))) {
        // Terminate iteration
        return NO;
      }
    }
  }
  return YES;
}

- (BOOL)traverseOpenCells:(BOOL(^)(CGPoint))block {
  BOOL allTakenBefore = YES;
  NSUInteger unboundIndex = 0;

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      unboundIndex = (NSUInteger)self.firstOpenSpace.y;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unboundIndex = (NSUInteger)self.firstOpenSpace.x;
      break;
  }

  do {
    NSUInteger boundIndex = 0;

    for(boundIndex = 0; boundIndex < self.maximumNumberOfItemsInBounds; boundIndex++) {

      CGPoint point = CGPointZero;

      switch (self.scrollDirection) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(boundIndex, unboundIndex);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unboundIndex, boundIndex);
          break;
      }

      if([self indexPathForPosition:point]) {
        continue;
      }

      if(allTakenBefore) {
        self.firstOpenSpace = point;
        allTakenBefore = NO;
      }

      if(!block(point)) {
        // break;
        return NO;
      }
    }

    unboundIndex++;
  } while (true);

  NSAssert(0, @"Unable to find a insertion point for a cell.");

  return YES;
}

#pragma mark Getters

- (CGRect)rectForIndexPath:(NSIndexPath *)path {
  CGPoint position = [self positionForIndexPath:path];
  CGSize elementSize = [self sizeForCellAtIndexPath:path];
  CGFloat padding = 0.0f;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical: {
      CGFloat width = CGRectGetWidth(contentRect);
      // Because the cells vary in size, we must pad the cells to center them on the view. This will
      // create a margin on either side.
      padding = (width - self.maximumNumberOfItemsInBounds * self.cellSize.width) / 2;

      return CGRectMake(position.x * self.cellSize.width + padding,   // x
                        position.y * self.cellSize.height,            // y
                        elementSize.width * self.cellSize.width,      // width
                        elementSize.height * self.cellSize.height);   // height

    }

    case UICollectionViewScrollDirectionHorizontal: {
      CGFloat height = CGRectGetHeight(contentRect);
      padding = (height - self.maximumNumberOfItemsInBounds * self.cellSize.height) / 2;

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
                                  layout:self
                  sizeForItemAtIndexPath:indexPath];
  }

  return size;
}

- (CGPoint)positionForIndexPath:(NSIndexPath *)path {
  // if item does not have a position, we will make one!
  if(!self.positionByIndexPath[@(path.section)][@(path.row)]) {
    [self insertCellsToIndexPath:path];
  }

  return [self.positionByIndexPath[@(path.section)][@(path.row)] CGPointValue];
}

- (NSIndexPath *)indexPathForPosition:(CGPoint)position {
  NSNumber *unboundPoint, *boundPoint;

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      unboundPoint = @(position.y);
      boundPoint = @(position.x);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unboundPoint = @(position.x);
      boundPoint = @(position.y);
      break;
  }

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  return self.indexPathByPosition[boundPoint][unboundPoint];
}

#pragma mark Setters
- (void)setPosition:(CGPoint)point forIndexPath:(NSIndexPath *)indexPath {

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  NSNumber *unboundPoint, *boundPoint;

  switch (self.scrollDirection) {
    case UICollectionViewScrollDirectionVertical:
      unboundPoint = @(point.y);
      boundPoint = @(point.x);
      break;

    default:
      unboundPoint = @(point.x);
      boundPoint = @(point.y);
      break;
  }
  
  // If no value is set for the index `boundPoint`, create a new dictionary
  if (!self.indexPathByPosition[boundPoint]) {
    self.indexPathByPosition[boundPoint] = [NSMutableDictionary dictionary];
  }
  
  self.indexPathByPosition[boundPoint][unboundPoint] = indexPath;
}

- (void)setIndexPath:(NSIndexPath *)path forPosition:(CGPoint)point {
  // If no value is set for the index `@(path.section)`, create a new dictionary
  if (!self.positionByIndexPath[@(path.section)]) {
    self.positionByIndexPath[@(path.section)] = [NSMutableDictionary dictionary];
  }
  
  self.positionByIndexPath[@(path.section)][@(path.row)] = [NSValue valueWithCGPoint:point];
}

@end
