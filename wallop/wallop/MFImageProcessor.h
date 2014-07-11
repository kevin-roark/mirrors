//
//  MFImageProcessor.h
//  wallop
//
//  Created by Kevin Roark on 7/11/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFImageProcessor : NSObject

+ (UIImage *)image:(UIImage *)image withTint:(UIColor *)tintColor alpha:(CGFloat)alpha;

+ (UIImage *)image:(UIImage *)image withBrightnessBoost:(CGFloat)percent;

+ (UIImage *)imageWithRandomTint:(UIImage *)image;
+ (UIImage *)imageWithRandomBrightness:(UIImage *)image;

@end
