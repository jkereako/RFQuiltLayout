//
//  RFQuiltLayout.h
//
//  Created by Bryce Redd on 12/7/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "RFQuiltLayout.h"

@interface RFQuiltLayout ()

@property(nonatomic) CGPoint firstOpenSpace;
@property(nonatomic) CGPoint furthestBlockPoint;

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

- (void)initialize;
- (void)fillInBlocksToIndexPath:(NSIndexPath *)path;
- (BOOL)placeBlockAtIndex:(NSIndexPath*)indexPath;
- (BOOL)traverseTilesBetweenUnrestrictedDimension:(NSUInteger)start and:(NSUInteger)end
                                         iterator:(BOOL(^)(CGPoint))block;
- (BOOL)traverseTilesForPoint:(CGPoint)point withSize:(CGSize)size iterator:(BOOL(^)(CGPoint))block;
- (void)clearPositions;
- (NSIndexPath *)indexPathForPosition:(CGPoint)point;
- (CGPoint)coordinateForIndexPath:(NSIndexPath *)path;
- (void)setCoordinate:(CGPoint)point forIndexPath:(NSIndexPath *)indexPath;
- (void)fillInBlocksToUnrestrictedRow:(NSUInteger)endRow;
- (CGSize)getBlockSizeForItemAtIndexPath:(NSIndexPath *)indexPath;
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
  self.blockPixels = CGSizeMake(100.f, 100.f);
}

#pragma mark - Overridden methods
- (CGSize)collectionViewContentSize {
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      return CGSizeMake(CGRectGetWidth(contentRect),
                        (self.furthestBlockPoint.y + 1) * self.blockPixels.height);

    case UICollectionViewScrollDirectionHorizontal:
      return CGSizeMake((self.furthestBlockPoint.x + 1) * self.blockPixels.width,
                        CGRectGetHeight(contentRect));
  }
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
  if (!self.delegate) {
    @throw([NSException exceptionWithName:@"NotFound" reason:@"Delegate not set" userInfo:nil]);
  }

  // see the comment on these properties
  if(CGRectEqualToRect(rect, self.layoutRectCache)) {
    return self.layoutAttributesCache;
  }

  self.layoutRectCache = rect;

  NSUInteger unrestrictedDimensionStart = 0;
  NSUInteger unrestrictedDimensionLength = 0;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedDimensionStart = (NSUInteger)(rect.origin.y / self.blockPixels.height);
      unrestrictedDimensionLength = (NSUInteger)(rect.size.height / self.blockPixels.height);
      break;

    default:
      unrestrictedDimensionStart = (NSUInteger)(rect.origin.x / self.blockPixels.width);
      unrestrictedDimensionLength = (NSUInteger)((rect.size.width / self.blockPixels.width) + 1);
      break;
  }

  NSUInteger unrestrictedDimensionEnd = unrestrictedDimensionStart + unrestrictedDimensionLength;

  [self fillInBlocksToUnrestrictedRow:self.prelayoutEverything ? INT_MAX : unrestrictedDimensionEnd];

  // find the indexPaths between those rows
  NSMutableSet* attributes = [NSMutableSet set];
  [self traverseTilesBetweenUnrestrictedDimension:unrestrictedDimensionStart
                                              and:unrestrictedDimensionEnd
                                         iterator:^(CGPoint point) {
                                           NSIndexPath* indexPath = [self indexPathForPosition:point];

                                           if(indexPath) {
                                             [attributes addObject:[self layoutAttributesForItemAtIndexPath:indexPath]];
                                           }

                                           return YES;
                                         }];

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

  _furthestBlockPoint = CGPointZero;
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
      unrestrictedRow = (NSUInteger)(CGRectGetMaxY(scrollFrame) / [self blockPixels].height) + 1;
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unrestrictedRow = (NSUInteger)(CGRectGetMaxY(scrollFrame) / [self blockPixels].width) + 1;
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
  _blockPixels = size;

  [self invalidateLayout];
}

- (void) setFurthestBlockPoint:(CGPoint)point {
  _furthestBlockPoint = CGPointMake(MAX(self.furthestBlockPoint.x, point.x),
                                    MAX(self.furthestBlockPoint.y, point.y)
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

    for (NSInteger row = (!self.indexPathCache? 0 : self.indexPathCache.row + 1); row < numRows; row++) {
      NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self placeBlockAtIndex:indexPath]) {
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

- (void)fillInBlocksToIndexPath:(NSIndexPath *)path {

  // we'll have our data structure as if we're planning
  // a vertical layout, then when we assign positions to
  // the items we'll invert the axis

  NSInteger numSections = [self.collectionView numberOfSections];
  for (NSInteger section=self.indexPathCache.section; section<numSections; section++) {
    NSInteger numRows = [self.collectionView numberOfItemsInSection:section];

    for (NSInteger row = (!self.indexPathCache ? 0 : self.indexPathCache.row + 1); row < numRows; row++) {

      // exit when we are past the desired row
      if(section >= path.section && row > path.row) {
        return;
      }

      NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:section];

      if([self placeBlockAtIndex:indexPath]) {
        self.indexPathCache = indexPath;
      }

    }
  }
}

- (BOOL)placeBlockAtIndex:(NSIndexPath*)indexPath {
  CGSize blockSize = [self getBlockSizeForItemAtIndexPath:indexPath];
  BOOL vert = self.direction == UICollectionViewScrollDirectionVertical;

  return ![self traverseOpenTiles:^(CGPoint blockOrigin) {

    // we need to make sure each square in the desired
    // area is available before we can place the square

    BOOL didTraverseAllBlocks = [self traverseTilesForPoint:blockOrigin
                                                   withSize:blockSize
                                                   iterator:^(CGPoint point) {
                                                     BOOL spaceAvailable = (BOOL)![self indexPathForPosition:point];
                                                     BOOL inBounds = (vert? point.x : point.y) < [self restrictedDimensionBlockSize];
                                                     BOOL maximumRestrictedBoundSize = (vert? blockOrigin.x : blockOrigin.y) == 0;

                                                     if (spaceAvailable && maximumRestrictedBoundSize && !inBounds) {
                                                       NSLog(@"%@: layout is not %@ enough for this piece size: %@! Adding anyway...", [self class], vert? @"wide" : @"tall", NSStringFromCGSize(blockSize));
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

    [self traverseTilesForPoint:blockOrigin
                       withSize:blockSize
                       iterator:^(CGPoint point) {
                         [self setCoordinate:point forIndexPath:indexPath];

                         self.furthestBlockPoint = point;

                         return YES;
                       }];

    return NO;
  }];
}

// returning no in the callback will
// terminate the iterations early
- (BOOL)traverseTilesBetweenUnrestrictedDimension:(NSUInteger)start and:(NSUInteger)end
                                         iterator:(BOOL(^)(CGPoint))block {

  // the double ;; is deliberate, the unrestricted dimension should iterate indefinitely
  for(NSUInteger unrestrictedDimension = start; unrestrictedDimension < end; unrestrictedDimension ++) {
    for(NSUInteger restrictedDimension = 0; restrictedDimension < [self restrictedDimensionBlockSize]; restrictedDimension++) {

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

// returning no in the callback will
// terminate the iterations early
- (BOOL)traverseTilesForPoint:(CGPoint)point withSize:(CGSize)size iterator:(BOOL(^)(CGPoint))block {

  for(NSUInteger col = (NSUInteger)point.x; col < point.x + size.width; col++) {
    for (NSUInteger row = (NSUInteger)point.y; row < point.y + size.height; row++) {

      if(!block(CGPointMake(col, row))) {
        return NO;
      }
    }
  }
  return YES;
}

// returning no in the callback will
// terminate the iterations early
- (BOOL)traverseOpenTiles:(BOOL(^)(CGPoint))block {
  BOOL allTakenBefore = YES;
  BOOL isVert = self.direction == UICollectionViewScrollDirectionVertical;

  // the double ;; is deliberate, the unrestricted dimension should iterate indefinitely
  for(NSUInteger unrestrictedDimension = (isVert? self.firstOpenSpace.y : self.firstOpenSpace.x);; unrestrictedDimension++) {
    for(int restrictedDimension = 0; restrictedDimension<[self restrictedDimensionBlockSize]; restrictedDimension++) {

      CGPoint point = CGPointZero;

      switch (self.direction) {
        case UICollectionViewScrollDirectionVertical:
          point = CGPointMake(restrictedDimension, unrestrictedDimension);
          break;

        case UICollectionViewScrollDirectionHorizontal:
          point = CGPointMake(unrestrictedDimension, restrictedDimension);
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

- (NSIndexPath*)indexPathForPosition:(CGPoint)point {
  NSNumber *unrestrictedPoint, *restrictedPoint;

  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical:
      unrestrictedPoint = @(point.y);
      restrictedPoint = @(point.x);
      break;

    case UICollectionViewScrollDirectionHorizontal:
      unrestrictedPoint = @(point.x);
      restrictedPoint = @(point.y);
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
  CGSize elementSize = [self getBlockSizeForItemAtIndexPath:path];
  CGFloat initialPaddingForContraintedDimension = 0.0;
  CGRect contentRect = UIEdgeInsetsInsetRect(self.collectionView.frame,
                                             self.collectionView.contentInset);
  switch (self.direction) {
    case UICollectionViewScrollDirectionVertical: {

      initialPaddingForContraintedDimension = (CGRectGetWidth(contentRect) - [self restrictedDimensionBlockSize] * self.blockPixels.width) / 2;
      return CGRectMake(position.x * self.blockPixels.width + initialPaddingForContraintedDimension,
                        position.y * self.blockPixels.height,
                        elementSize.width * self.blockPixels.width,
                        elementSize.height * self.blockPixels.height);

    }

    case UICollectionViewScrollDirectionHorizontal: {
      initialPaddingForContraintedDimension = (CGRectGetHeight(contentRect) - [self restrictedDimensionBlockSize] * self.blockPixels.height) / 2;
      return CGRectMake(position.x * self.blockPixels.width,
                        position.y * self.blockPixels.height + initialPaddingForContraintedDimension,
                        elementSize.width * self.blockPixels.width,
                        elementSize.height * self.blockPixels.height);

    }
  }
}


//This method is prefixed with get because it may return its value indirectly
- (CGSize)getBlockSizeForItemAtIndexPath:(NSIndexPath *)indexPath {
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
      size = (NSUInteger)(CGRectGetWidth(contentRect) / self.blockPixels.width);
      break;
      
    case UICollectionViewScrollDirectionHorizontal:
      size = (NSUInteger)(CGRectGetHeight(contentRect) / self.blockPixels.height);
  }
  
  if(size == 0) {
    NSLog(@"Cannot fit block of size: %@ in content rect %@!  Defaulting to 1", NSStringFromCGSize(self.blockPixels), NSStringFromCGRect(contentRect));
    return 1;
  }
  
  return size;
}

@end
