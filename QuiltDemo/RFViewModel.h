//
//  RFViewModel.h
//  QuiltDemo
//
//  Created by Jeffrey Kereakoglow on 12/8/15.
//  Copyright © 2015 Bryce Redd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RFQuiltLayout.h"

@class RFViewController;

@interface RFViewModel : NSObject <RFQuiltLayoutDelegate>

@property (nonatomic) RFViewController *viewController;
@property (nonatomic, readonly) NSArray *numbers;

@end
