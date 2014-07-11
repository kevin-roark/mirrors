//
//  MFImageProcessor.m
//  wallop
//
//  Created by Kevin Roark on 7/11/14.
//  Copyright (c) 2014 Miller's Fantasy. All rights reserved.
//

#import "MFImageProcessor.h"

#define ARC4RANDOM_MAX 0x100000000

@implementation MFImageProcessor

+ (UIImage *)image:(UIImage *)image withTint:(UIColor *)tintColor alpha:(CGFloat)alpha {
    
    // Begin drawing
    CGRect aRect = CGRectMake(0.f, 0.f, image.size.width, image.size.height);
    UIGraphicsBeginImageContext(aRect.size);
    
    // Get the graphic context
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    // Converting a UIImage to a CGImage flips the image,
    // so apply a upside-down translation
    CGContextTranslateCTM(c, 0, image.size.height);
    CGContextScaleCTM(c, 1.0, -1.0);
    
    // Draw the image
    [image drawInRect:aRect];
    
    // Set the fill color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextSetFillColorSpace(c, colorSpace);
    
    // Set the mask to only tint non-transparent pixels
    CGContextClipToMask(c, aRect, image.CGImage);
    
    // Set the fill color
    CGContextSetFillColorWithColor(c, [tintColor colorWithAlphaComponent:alpha].CGColor);
    
    UIRectFillUsingBlendMode(aRect, kCGBlendModeColor);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Release memory
    CGColorSpaceRelease(colorSpace);
    
    return img;
}

+ (UIImage *)image:(UIImage *)image withBrightnessBoost:(CGFloat)percent
{
    CGFloat brightness = percent;
    
    UIGraphicsBeginImageContext(image.size);
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Original image
    [image drawInRect:imageRect];
    
    // Brightness overlay
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1.0f alpha:brightness].CGColor);
    CGContextAddRect(context, imageRect);
    CGContextFillPath(context);
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

+ (UIImage *)imageWithRandomTint:(UIImage *)image
{
    double red = ((double) arc4random() / ARC4RANDOM_MAX);
    double green = ((double) arc4random() / ARC4RANDOM_MAX);
    double blue = ((double) arc4random() / ARC4RANDOM_MAX);
    
    return [self image:image withTint:[UIColor colorWithRed:red green:green blue:blue alpha:1.0f] alpha:1.0f];
}

+ (UIImage *)imageWithRandomBrightness:(UIImage *)image
{
    double brightness = ((double) arc4random() / ARC4RANDOM_MAX) * 0.5;
        
    return [self image:image withBrightnessBoost:brightness];
}

@end
