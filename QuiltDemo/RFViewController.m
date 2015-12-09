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

@end

@implementation RFViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Fetch the collection view layout and set the properties
  RFQuiltLayout *layout = (RFQuiltLayout *)self.collectionView.collectionViewLayout;
  layout.direction = UICollectionViewScrollDirectionVertical;
  layout.cellSize = CGSizeMake(75, 75);
}

- (void) viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [self.collectionView reloadData];
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
  NSIndexPath *toRemove = [visibleIndexPaths objectAtIndex:(arc4random() % visibleIndexPaths.count)];

  RFViewController * __weak weakSelf = self;

  self.animating = YES;

  [self.viewModel collectionView:self.collectionView
                 removeIndexPath:toRemove
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

@end
