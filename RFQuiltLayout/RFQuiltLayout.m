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

@property(nonatomic, readonly) NSUInteger restrictedDimensionBlockSize;

- (void)initialize;
- (void)fillInBlocksToIndexPath:(NSIndexPath *)indexPath;
- (BOOL)insertCellAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)traverseCellsBetweenUnrestrictedDimension:(NSUInteger)start and:(NSUInteger)end
                                         iterator:(BOOL(^)(CGPoint))block;
- (BOOL)traverseCellsForCoordinate:(CGPoint)point withSize:(CGSize)size iterator:(BOOL(^)(CGPoint))block;
- (BOOL)traverseOpenCells:(BOOL(^)(CGPoint))block;
- (void)clearPositions;
- (NSIndexPath *)indexPathForCoordinate:(CGPoint)coordinate;
- (CGPoint)coordinateForIndexPath:(NSIndexPath *)path;
- (void)setCoordinate:(CGPoint)point forIndexPath:(NSIndexPath *)indexPath;
- (void)fillInBlocksToUnrestrictedRow:(NSUInteger)endRow;
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

  NSUInteger unrestrictedDimensionStart = 0;
  NSUInteger unrestrictedDimensionLength = 0;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedDimensionStart = (NSUInteger)(rect.origin.y / self.cellSize.height);
      unrestrictedDimensionLength = (NSUInteger)(rect.size.height / self.cellSize.height);
      break;

    default:
      unrestrictedDimensionStart = (NSUInteger)(rect.origin.x / self.cellSize.width);
      unrestrictedDimensionLength = (NSUInteger)((rect.size.width / self.cellSize.width) + 1);
      break;
  }

  NSUInteger unrestrictedDimensionEnd = unrestrictedDimensionStart + unrestrictedDimensionLength;

  [self fillInBlocksToUnrestrictedRow:self.prelayoutEverything ? INT_MAX : unrestrictedDimensionEnd];

  // find the indexPaths between those rows
  NSMutableSet *attributes = [NSMutableSet set];
  [self traverseCellsBetweenUnrestrictedDimension:unrestrictedDimensionStart
                                              and:unrestrictedDimensionEnd
                                         iterator:^(CGPoint point) {
                                           NSIndexPath* indexPath = [self indexPathForCoordinate:point];

                                           if(indexPath) {
                                             [attributes addObject:[self layoutAttributesForItemAtIndexPath:indexPath]];
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

  NSUInteger unrestrictedRow = 0;
  CGRect scrollFrame = CGRectMake(self.collectionView.contentOffset.x,
                                  self.collectionView.contentOffset.y,
                                  self.collectionView.frame.size.width,
                                  self.collectionView.frame.size.height);
  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedRow = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.height) + 1;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unrestrictedRow = (NSUInteger)(CGRectGetMaxY(scrollFrame) / self.cellSize.width) + 1;
      break;
  }

  [self fillInBlocksToUnrestrictedRow:self.prelayoutEverything? INT_MAX : unrestrictedRow];
}

#pragma mark - Setters
- (void)setDirection:(UICollectionViewScrollDirection)direction {
  _direction = direction;

  [self invalidateLayout];
}

- (void)setBlockPixels:(CGSize)size {
  _cellSize = size;

  [self invalidateLayout];
}

- (void) setFurthestBlockCoordinate:(CGPoint)point {
  _furthestBlockCoordinate = CGPointMake(MAX(_furthestBlockCoordinate.x, point.x),
                                         MAX(_furthestBlockCoordinate.y, point.y)
                                         );
}

#pragma mark - Private methods
- (void)fillInBlocksToUnrestrictedRow:(NSUInteger)endRow {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger numSections = [self.collectionView numberOfSections];
  for (NSInteger section = self.indexPathCache.section; section < numSections; section++) {
    NSInteger numRows = [self.collectionView numberOfItemsInSection:section];

    for (NSInteger row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1); row < numRows; row++) {
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

      NSIndexPath *newCellIndexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self insertCellAtIndexPath:newCellIndexPath]) {
        // Cache the index path
        self.indexPathCache = newCellIndexPath;
      }

    }
  }
}

- (BOOL)insertCellAtIndexPath:(NSIndexPath *)indexPath {
  CGSize cellSize = [self sizeForCellAtIndexPath:indexPath];
  BOOL vert = self.direction == UICollectionViewScrollDirectionVertical;

  return ![self traverseOpenCells:^(CGPoint blockOrigin) {

    // we need to make sure each square in the desired
    // area is available before we can place the square

    BOOL didTraverseAllBlocks = [self traverseCellsForCoordinate:blockOrigin
                                                   withSize:cellSize
                                                   iterator:^(CGPoint point) {
                                                     BOOL spaceAvailable = (BOOL)![self indexPathForCoordinate:point];
                                                     BOOL inBounds = (vert? point.x : point.y) < self.restrictedDimensionBlockSize;
                                                     BOOL maximumRestrictedBoundSize = (vert? blockOrigin.x : blockOrigin.y) == 0;

                                                     if (spaceAvailable && maximumRestrictedBoundSize && !inBounds) {
                                                       NSLog(@"%@: layout is not %@ enough for this piece size: %@! Adding anyway...", [self class], vert? @"wide" : @"tall", NSStringFromCGSize(cellSize));
                                                       return YES;
                                                     }

                                                     return (BOOL) (spaceAvailable && inBounds);
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
- (BOOL)traverseCellsBetweenUnrestrictedDimension:(NSUInteger)start and:(NSUInteger)end
                                         iterator:(BOOL(^)(CGPoint))block {

  // the double ;; is deliberate, the unrestricted dimension should iterate indefinitely
  for(NSUInteger unrestrictedDimension = start; unrestrictedDimension < end; unrestrictedDimension ++) {
    for(NSUInteger restrictedDimension = 0; restrictedDimension < self.restrictedDimensionBlockSize; restrictedDimension++) {

      CGPoint point = CGPointZero;

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(restrictedDimension, unrestrictedDimension);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unrestrictedDimension, restrictedDimension);
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
  BOOL isVert = self.direction == UICollectionViewScrollDirectionVertical;

  // the double ;; is deliberate, the unrestricted dimension should iterate indefinitely
  for(NSUInteger unrestrictedDimension = (isVert? self.firstOpenSpace.y : self.firstOpenSpace.x);; unrestrictedDimension++) {
    for(int restrictedDimension = 0; restrictedDimension < self.restrictedDimensionBlockSize; restrictedDimension++) {

      CGPoint point = CGPointZero;

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(restrictedDimension, unrestrictedDimension);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unrestrictedDimension, restrictedDimension);
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
  }

  NSAssert(0, @"Could find no good place for a block!");
  return YES;
}

- (void)clearPositions {
  self.indexPathByPosition = [NSMutableDictionary dictionary];
  self.positionByIndexPath = [NSMutableDictionary dictionary];
}

- (NSIndexPath*)indexPathForCoordinate:(CGPoint)coordinate {
  NSNumber *unrestrictedPoint, *restrictedPoint;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedPoint = @(coordinate.y);
      restrictedPoint = @(coordinate.x);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unrestrictedPoint = @(coordinate.x);
      restrictedPoint = @(coordinate.y);
      break;
  }

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  return self.indexPathByPosition[restrictedPoint][unrestrictedPoint];
}

- (void)setCoordinate:(CGPoint)point forIndexPath:(NSIndexPath*)indexPath {

  // to avoid creating unbounded nsmutabledictionaries we should
  // have the innerdict be the unrestricted dimension

  NSNumber *unrestrictedPoint, *restrictedPoint;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedPoint = @(point.y);
      restrictedPoint = @(point.x);
      break;

    default:
      unrestrictedPoint = @(point.x);
      restrictedPoint = @(point.y);
      break;
  }

  NSMutableDictionary* innerDict = self.indexPathByPosition[restrictedPoint];

  if (!innerDict) {
    self.indexPathByPosition[restrictedPoint] = [NSMutableDictionary dictionary];
  }

  self.indexPathByPosition[restrictedPoint][unrestrictedPoint] = indexPath;
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
  CGFloat initialPaddingForContraintedDimension = 0.0;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical: {

      initialPaddingForContraintedDimension = (CGRectGetWidth(contentRect) - self.restrictedDimensionBlockSize * self.cellSize.width) / 2;
      return CGRectMake(position.x * self.cellSize.width + initialPaddingForContraintedDimension,
                        position.y * self.cellSize.height,
                        elementSize.width * self.cellSize.width,
                        elementSize.height * self.cellSize.height);

    }

    case UICollectionViewScrollDirectionHorizontal: {
      initialPaddingForContraintedDimension = (CGRectGetHeight(contentRect) - self.restrictedDimensionBlockSize * self.cellSize.height) / 2;
      return CGRectMake(position.x * self.cellSize.width,
                        position.y * self.cellSize.height + initialPaddingForContraintedDimension,
                        elementSize.width * self.cellSize.width,
                        elementSize.height * self.cellSize.height);

    }
  }
}


//This method is prefixed with get because it may return its value indirectly
- (CGSize)sizeForCellAtIndexPath:(NSIndexPath *)indexPath {
  CGSize blockSize = CGSizeMake(1, 1);

  if([self.delegate
      respondsToSelector:@selector(collectionView:layout:blockSizeForItemAtIndexPath:)]
     ) {
    blockSize = [self.delegate collectionView:[self collectionView]
                                       layout:self blockSizeForItemAtIndexPath:indexPath];
  }

  return blockSize;
}

/**
 Returns the maximum width, if using the horizontal layout, or height, if using the vertical layout,
 the collection view can hold.

 @returns Maximum width or height
 */
- (NSUInteger) restrictedDimensionBlockSize {
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
    NSLog(@"Cannot fit block of size: %@ in content rect %@!  Defaulting to 1", NSStringFromCGSize(self.cellSize), NSStringFromCGRect(contentRect));
    return 1;
  }
  
  return size;
}

@end
