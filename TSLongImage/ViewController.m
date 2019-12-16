//
//  ViewController.m
//  TSLongImage
//
//  Created by caoxuerui on 2019/11/15.
//  Copyright © 2019 caoxuerui. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIImage *screen1 = [UIImage imageNamed:@"Screen1"];
    UIImage *screen2 = [UIImage imageNamed:@"Screen2"];
    UIImage *screen3 = [UIImage imageNamed:@"Screen3"];
    
    UIImage *screen4 = [UIImage imageNamed:@"Screen4"];
    UIImage *screen5 = [UIImage imageNamed:@"Screen5"];
    UIImage *screen6 = [UIImage imageNamed:@"Screen6"];
    
    NSArray *screenArray = @[screen1, screen2, screen3];
//    NSArray *screenArray = @[screen4, screen5, screen6];
    
    [self mixImageWithArray:screenArray complete:^(UIImage *mixImage) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:mixImage];
        imageView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.view addSubview:imageView];
    }];
}

- (void)mixImageWithArray:(NSArray *)screenArray complete:(void (^)(UIImage *mixImage))complete {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSData *resultImageData = [[NSData alloc] init];// 结果图片的数据
        NSUInteger imageAddCount = 0;// 增加的行数
        for (UIImage *currentImage in screenArray) {
            CGImageRef imgref = currentImage.CGImage;
            size_t width = CGImageGetWidth(imgref);
            size_t height = CGImageGetHeight(imgref);
            size_t bytesPerRow = CGImageGetBytesPerRow(imgref);//每一行占用多少bytes 注意是bytes不是bits  1byte ＝ 8bit
            CGDataProviderRef currentDataProvider = CGImageGetDataProvider(imgref);
            
            CFDataRef currentData = CGDataProviderCopyData(currentDataProvider);
            CFDataRef resultCFData = CFBridgingRetain(resultImageData);
            if (resultImageData.length == 0) {
                // 如果是第一张图片直接返回
                resultImageData = (__bridge_transfer NSData *)currentData;
                continue;
            }
            
            UInt8 *currentBuffer = (UInt8*)CFDataGetBytePtr(currentData);// 当前图片的首地址
            UInt8 *resultBuffer = (UInt8*)CFDataGetBytePtr(resultCFData);// 结果图片的首地址
            
            NSUInteger i = 0, j = 0;// 循环临时变量
            NSUInteger diffCurrentStart = 0, diffCurrentEnd = 0;//用来记录 当前图片与结果图片的首个不相同的行号，和最后一个不相同的行号
            NSUInteger diffResultStart = 0, diffResultEnd = 0;// 结果图片与当前图片的首个不相同的行号，和最后一个不相同的行号
            // 从前开始逐行遍历像素矩阵，找出不一样的行
            for (i = 0; i < height; i++) {
                UInt8 *currentTmp = NULL;// 记录当前图片该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                BOOL outSideBreakFlag = NO;// 如果不同就中断遍历的flag
                for (j = 0; j < width; j++) {
                    currentTmp = currentBuffer + i * bytesPerRow + j * 4;
                    resultTmp = resultBuffer + i * bytesPerRow + j * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        if (
                            abs((int)*currentTmp - (int)*resultTmp) +
                            abs((int)*(currentTmp + 1) - (int)*(resultTmp + 1)) +
                            abs((int)*(currentTmp + 2) - (int)*(resultTmp + 2)) +
                            abs((int)*(currentTmp + 3) - (int)*(resultTmp + 3)) >= 20
                           ) {
                            // 异或，如果不相同，且它们RGBA四分量的绝对值之和大于20，则认为不同记录下该行的行数
                            diffCurrentStart = i;
                            diffResultStart = i;
                            outSideBreakFlag = YES;
                            break;
                        }
                    }
                }
                if (outSideBreakFlag == YES) {
                    break;
                }
            }
            
            // 从尾开始逐行遍历像素矩阵，找出不一样的行
            for (i = height, diffResultEnd = [resultImageData length] / bytesPerRow; i > 0; i--, diffResultEnd--) {
                UInt8 *currentTmp;// 记录该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                BOOL outSideBreakFlag = NO;
                for (j = 0; j < width; j++) {
                    currentTmp = currentBuffer + i * bytesPerRow + j * 4;
                    resultTmp = resultBuffer + diffResultEnd * bytesPerRow + j * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        if (
                            abs((int)*currentTmp - (int)*resultTmp) +
                            abs((int)*(currentTmp + 1) - (int)*(resultTmp + 1)) +
                            abs((int)*(currentTmp + 2) - (int)*(resultTmp + 2)) +
                            abs((int)*(currentTmp + 3) - (int)*(resultTmp + 3)) >= 20
                           ) {
                            // 异或，如果不相同，且它们RGBA四分量的绝对值之和大于20，则认为不同记录下该行的行数
                            diffCurrentEnd = i;
                            diffResultEnd = diffResultEnd;
                            outSideBreakFlag = YES;
                            break;
                        }
                    }
                }
                if (outSideBreakFlag) {
                    break;
                }
            }
            
            NSUInteger searchLength = (diffCurrentEnd - diffCurrentStart) * 10 / 100;// 保证有10%的重合率
            NSUInteger searchResultStart = diffResultEnd - searchLength;// 在结果图片中搜索的开始行
            NSUInteger searchCurrentStart = 0;// 当前图片中搜索结果的开始行
            NSUInteger searchCurrentEnd = 0;// 当前图片中搜索结果的结束行
            NSUInteger searchSamePercent = 0;// 重合率
            
            // 从结果图片的searchResultStart行开始查找searchLength的长度
            // 从当前图片的diffCurrentStart行开始查找searchLength的长度，如果有不一样的就直接结束searchCurrentStart++，开始查找下一行，如果searchLength的长度都相同，则认为匹配成功，记录下searchCurrentStart和searchCurrentEnd，如果searchCurrentStart == diffCurrentEnd则结果匹配
            for (i = diffCurrentStart; i < diffCurrentEnd; i++) {
                UInt8 *currentTmp;// 记录当前图片该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                NSUInteger outSideBreakFlag = 0;// 0：初始化状态，1：异步率大于5%，2：同步率大于95%，3：已经有相同行的前提下，偶然遇到一个不相同行
                NSUInteger synchronize = 0;// 同步率大于95%即认为该行相同
                NSUInteger asynchronize = 0;// 异步率大于5%则停止遍历该行
                for (j = 0; j < width; j++) {
                    currentTmp = currentBuffer + i * bytesPerRow + j * 4;
                    resultTmp = resultBuffer + searchResultStart * bytesPerRow + j * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        if (
                              abs((int)*currentTmp - (int)*resultTmp) +
                              abs((int)*(currentTmp + 1) - (int)*(resultTmp + 1)) +
                              abs((int)*(currentTmp + 2) - (int)*(resultTmp + 2)) +
                              abs((int)*(currentTmp + 3) - (int)*(resultTmp + 3)) >= 20
                        ) {
                            // 异或，如果不相同，且它们RGBA四分量的绝对值之和大于20，则认为该行不同，异步率+1
                            asynchronize++;
                            if (asynchronize > width * 5 / 100) {
                                outSideBreakFlag = 1;
                                break;
                            }
                        }
                    } else {
                        // 如果相同，则同步率+1
                        synchronize++;
                        if (synchronize > width * 95 / 100) {
                            outSideBreakFlag = 2;
                            break;
                        }
                    }
                }
                
                if (outSideBreakFlag == 1) {
                    // 该行不同
                    searchResultStart = diffResultEnd - searchLength;// 结果图片的查找开始行重置
                    searchSamePercent = 0;// 重合率重置
                } else if (outSideBreakFlag == 2) {
                    // 该行相同
                    searchSamePercent++;// 重合率+1
                    searchResultStart++;// 结果图片的查找行+1
                    if (searchSamePercent >= searchLength) {
                        searchCurrentEnd = i;// 记录结束的行数
                        break;
                    }
                }
            }
            
            imageAddCount = imageAddCount + diffCurrentEnd - searchCurrentEnd;// 每次遍历多出来的行数
            CFMutableDataRef resultMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, resultCFData);
            UInt8 *startByte = currentBuffer + searchCurrentEnd * bytesPerRow;// 新加上去的图片buffer的首地址
            CFRange deleteRange = CFRangeMake(diffResultEnd * bytesPerRow, CFDataGetLength(resultCFData) - diffResultEnd * bytesPerRow);// 需要替换的结果图片的尾部
            CFDataReplaceBytes(resultMutableDataRef, deleteRange, startByte, (height - searchCurrentEnd) * bytesPerRow);// 替换结果图片尾部为目标图片
            resultImageData = (__bridge_transfer NSData *)resultMutableDataRef;
        }
        
        UIImage *fistImage = [screenArray firstObject];
        CGImageRef imgref = fistImage.CGImage;
        size_t width = CGImageGetWidth(imgref);
        size_t height = CGImageGetHeight(imgref);
        size_t bitsPerComponent = CGImageGetBitsPerComponent(imgref);//图片每个颜色的bits
        size_t bitsPerPixel = CGImageGetBitsPerPixel(imgref);//每一个像素占用的bits
        size_t bytesPerRow = CGImageGetBytesPerRow(imgref);//每一行占用多少bytes 注意是bytes不是bits  1byte ＝ 8bit

        CGColorSpaceRef colorSpace = CGImageGetColorSpace(imgref);
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imgref);

        bool shouldInterpolate = CGImageGetShouldInterpolate(imgref);

        CGColorRenderingIntent intent = CGImageGetRenderingIntent(imgref);
        
        CGDataProviderRef effectedDataProvider = CGDataProviderCreateWithCFData(CFBridgingRetain(resultImageData));
        // 生成一张新的位图
        CGImageRef effectedCgImage = CGImageCreate(width, [resultImageData length] / bytesPerRow, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpace, bitmapInfo, effectedDataProvider, NULL, shouldInterpolate, intent);
        UIImage *effectedImage = [[UIImage alloc] initWithCGImage:effectedCgImage];

        CGImageRelease(effectedCgImage);
        CFRelease(effectedDataProvider);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                complete(effectedImage);
            }
        });
    });
}

@end
