//
//  GlobalVars.m
//  EvoApp
//
//  Created by Eric Kim on 2017-04-04.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "GlobalVars.h"

@implementation GlobalVars

@synthesize dict = _dict;

+ (GlobalVars *)sharedInstance {
  static dispatch_once_t onceToken;
  static GlobalVars *instance = nil;
  dispatch_once(&onceToken, ^{
    instance = [[GlobalVars alloc] init];
  });
  return instance;
}

- (UIImage *)getSharedUIImage:(NSString *)imageSrc {
  
  UIImage* cachedImage = dict[imageSrc];
  
  CGImageRef cgref = [cachedImage CGImage];
  CIImage *cim = [cachedImage CIImage];
  
  if (cim == nil && cgref == NULL) {
    UIImage *newImage;
    if ([imageSrc hasPrefix:@"http://"] || [imageSrc hasPrefix:@"https://"]){
      NSURL *url = [NSURL URLWithString:imageSrc];
      NSData *data = [NSData dataWithContentsOfURL:url];
      newImage = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
    } else {
      newImage = [UIImage imageWithContentsOfFile:imageSrc];
    }
    dict[imageSrc] = newImage;
    return newImage;
  } else {
    return cachedImage;
  }
}

- (UIImage *)getSharedUIImageWithKey:(NSString *)key {
  UIImage* cachedImage = dict[key];
  return cachedImage;
}

- (void)setSharedUIImageWithKey:(NSString *)key withUIImage:(UIImage *)image {
  dict[key] = image;
}

- (id)init {
  self = [super init];
  if (self) {
    dict = [[NSMutableDictionary alloc] init];
  }
  return self;
}

@end
