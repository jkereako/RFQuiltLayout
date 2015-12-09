# Changes
This is a cleaned-up version of RFQuiltLayout. I'm doing this to prepare for a
Swift version of this project.

The most difficult part of this project is understanding what "unrestricted dimension" and "restricted dimension" mean. It means that if your collection view scrolls horizonatally, then the restricted dimension is the number of columns while the unrestricted dimension is the number of rows. Vice versa for vertically scrolling collection views.

RFQUILTLAYOUT
=============

RFQuiltLayout is a [UICollectionViewLayout](http://developer.apple.com/library/ios/#documentation/UIKit/Reference/UICollectionViewLayout_class/Reference/Reference.html#//apple_ref/occ/cl/UICollectionViewLayout) subclass, used as the layout object of [UICollectionView](http://developer.apple.com/library/ios/#documentation/UIKit/Reference/UICollectionView_class/Reference/Reference.html). 

![Demo 1](http://i.imgur.com/BcQhwzR.png)
![Demo 2](http://i.imgur.com/hoBWCis.png)


Installation
------------

Add the layout as the subclass of your UICollectionViewLayout.

![Subclass the layout](http://i.imgur.com/vlqqKjP.png)


*Make sure you set the delegate of the flow layout*

    - (void) viewDidLoad {
      // ...

      RFQuiltLayout* layout = (id)[self.collectionView collectionViewLayout];
      layout.direction = UICollectionViewScrollDirectionVertical;
      layout.blockPixels = CGSizeMake(100, 100);
    }
    
    - (CGSize) blockSizeForItemAtIndexPath:(NSIndexPath *)indexPath {
        if (indexPath.row % 2 == 0)
            return CGSizeMake(2, 1);
        
        return CGSizeMake(1, 2);
    }

(Note: all delegate methods and properties are optional)


