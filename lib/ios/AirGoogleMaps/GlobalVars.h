//
//  GlobalVars.h
//  EvoApp
//
//  Created by Eric Kim on 2017-04-04.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GlobalVars : NSObject
{
  NSMutableDictionary *dict;
}

+ (GlobalVars *)sharedInstance;

- (UIImage *)getSharedUIImage:(NSString *)imageSrc;
- (UIImage *)getSharedUIImageWithKey:(NSString *)key;
- (void)setSharedUIImageWithKey:(NSString *)key withUIImage:(UIImage *)image;

@property(strong, nonatomic, readwrite) NSMutableDictionary *dict;

@end
