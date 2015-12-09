//
//  RFViewController.m
//  QuiltDemo
//
//  Created by Bryce Redd on 12/26/12.
//  Copyright (c) 2012 Bryce Redd. All rights reserved.
//

#import "RFViewController.h"
#import "RFViewModel.h"

@interface RFViewController () <UICollectionViewDelegate>

@property (nonatomic, readwrite, weak) IBOutlet RFViewModel *viewModel;
@property (nonatomic, readwrite, weak) IBOutlet UICollectionView *collectionView;

@property (nonatomic, readwrite, getter=isAnimating) BOOL animating;

- (IBAction)add:(UIBarButtonItem *)sender;
- (IBAction)remove:(UIBarButtonItem *)sender;
- (IBAction)refresh:(UIBarButtonItem *)sender;

- (UIColor *)colorForNumber:(NSNumber *)number;

@end

@implementation RFViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Fetch the collection view layout and set the properties
  RFQuiltLayout *layout = (RFQuiltLayout *)self.collectionView.collectionViewLayout;
  layout.direction = UICollectionViewScrollDirectionVertical;
  layout.cellSize = CGSizeMake(75, 75);

  // The only delegate method `viewModel` invokes is `configureCell:withObject:`. It is the proper
  // way to communicate between model and controller.
  self.viewModel.delegate = self;
}

- (void) viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [self.collectionView reloadData];
}

#pragma mark - RFCollectionViewControllerDelegate
- (void)configureCell:(UICollectionViewCell *)cell withObject:(id)object {
  // Check for nil
  NSParameterAssert(cell);
  NSParameterAssert(object);

  NSNumber *number = (NSNumber *)object;
  cell.backgroundColor = [self colorForNumber: number];

  // Fetch the label as defined in the storyboard and assign the `object` to it's `text` property.
  UILabel* label = (UILabel *)[cell viewWithTag:5];
  label.text = [NSString stringWithFormat:@"%@", number];
}

#pragma mark - Actions
- (IBAction)add:(UIBarButtonItem * __unused)sender {
  if (self.isAnimating) {
    return;
  }

  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];

  RFViewController * __weak weakSelf = self;

  self.animating = YES;

  if (!visibleIndexPaths.count) {
    [self.viewModel collectionView:self.collectionView
                      addIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                   completionBlock:^(void){
                     weakSelf.animating = NO;
                   }];

    return;
  }

  [self.viewModel collectionView:self.collectionView
                    addIndexPath:visibleIndexPaths[0]
                 completionBlock:^(void){
                   weakSelf.animating = NO;
                 }];

}

- (IBAction)remove:(UIBarButtonItem * __unused)sender {
  if (self.isAnimating) {
    return;
  }

  NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
  // Select a random index path
  NSIndexPath *indexPath = [visibleIndexPaths objectAtIndex:(arc4random() % visibleIndexPaths.count)];

  RFViewController * __weak weakSelf = self;

  self.animating = YES;

  [self.viewModel collectionView:self.collectionView
                 removeIndexPath:indexPath
                 completionBlock:^(void){
                   weakSelf.animating = NO;
                 }];

}

- (IBAction)refresh:(UIBarButtonItem * __unused)sender {
  [self.viewModel refreshData];
  [self.collectionView reloadData];
}

#pragma mark - UICollectionView Delegate
- (void)collectionView:(UICollectionView * __unused)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

  if (self.isAnimating) {
    return;
  }

  RFViewController * __weak weakSelf = self;

  self.animating = YES;

  [self.viewModel collectionView:self.collectionView
                 removeIndexPath:indexPath
                 completionBlock:^(void){
                   weakSelf.animating = NO;
                 }];
}

#pragma mark - Helpers
- (UIColor *)colorForNumber:(NSNumber *)number {
  return [UIColor colorWithHue:((19 * number.intValue) % 255)/255.f
                    saturation:1.f
                    brightness:1.f
                         alpha:1.f];
}

@end
