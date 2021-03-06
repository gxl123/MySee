//
//  VideoDecoder.h
//  MySee
//
//  Created by tommy on 15/10/22.
//  Copyright (c) 2015年 ml . All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "avcodec.h"
#import "swscale.h"
#import <AudioToolbox/AudioToolbox.h>
@protocol VideoDecoderDelegate;
@interface VideoDecoder : NSObject
@property (nonatomic, assign) id<VideoDecoderDelegate> delegate;


-(void)deInit;
-(void)push:(NSObject *)obj;
@end

@protocol VideoDecoderDelegate <NSObject>
- (void) didReceiveRGBData:(const char*)data DataSize:(NSInteger)size;
- (void) didReceiveImage:(UIImage*)data;
@end