//
//  ViewController.h
//  myo
//
//  Created by Larry Wang on 3/11/15.
//  Copyright (c) 2015 Larry Wang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (BOOL) isLeftConnected;
- (BOOL) isRightConnected;

//Returns UUID of associated Myo. Does not mean necessarily connected.
- (NSUUID *) getLeftMyoID;
- (NSUUID *) getRightMyoID;

@end


