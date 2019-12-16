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
    
    UIImage *screen7 = [UIImage imageNamed:@"Screen7"];
    
//    NSArray *screenArray = @[screen7, screen3];
//    NSArray *screenArray = @[screen1, screen2, screen3];
    NSArray *screenArray = @[screen4, screen5, screen6];
//    [self mixImageWithArray:screenArray complete:^(UIImage *mixImage) {
//        UIImageView *imageView = [[UIImageView alloc] initWithImage:mixImage];
//        imageView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
//        imageView.contentMode = UIViewContentModeScaleAspectFit;
//        [self.view addSubview:imageView];
//    }];
    
    [self mixImageWithArray2:screenArray complete:^(UIImage *mixImage) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:mixImage];
        imageView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.view addSubview:imageView];
    }];
    
//    [self mixImageWithArray1:screenArray complete:^(UIImage *mixImage) {
//        NSLog(@"");
//    }];
}

- (void)mixImageWithArray:(NSArray *)screenArray complete:(void (^)(UIImage *mixImage))complete {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSData *resultImageData = [[NSData alloc] init];
        NSUInteger imageAddCount = 0;
        for (UIImage *currentImage in screenArray) {
            CGImageRef imgref = currentImage.CGImage;
            size_t width = CGImageGetWidth(imgref);
            size_t height = CGImageGetHeight(imgref);
            size_t bytesPerRow = CGImageGetBytesPerRow(imgref);//每一行占用多少bytes 注意是bytes不是bits  1byte ＝ 8bit
            CGDataProviderRef dataProvider = CGImageGetDataProvider(imgref);
            
            CFDataRef data = CGDataProviderCopyData(dataProvider);
            CFDataRef resultCFData = CFBridgingRetain(resultImageData);
            if (resultImageData.length == 0) {
                resultImageData = (__bridge_transfer NSData *)data;
                continue;
            }
            UInt8 *buffer = (UInt8*)CFDataGetBytePtr(data);//Returns a read-only pointer to the bytes of a CFData object.// 首地址
            UInt8 *resultBuffer = (UInt8*)CFDataGetBytePtr(resultCFData);//Returns a read-only pointer to the bytes of a CFData object.// 首地址
            
            NSUInteger  i = 0, j = 0, diffStart = 0, diffEnd = 0, diffResultEnd = 0;
            // 从前开始逐行遍历像素矩阵，找出不一样的行
            for (i = 0; i < height; i++) {
                UInt8 *tmp;// 记录该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                BOOL outSideBreakFlag = NO;
                for (j = 0; j < width; j++) {
                    tmp = buffer + i * bytesPerRow + width * 4;
                    resultTmp = resultBuffer + i * bytesPerRow + width * 4;
                    if (*tmp ^ *resultTmp ^ *(tmp + 1) ^ *(resultTmp + 1) ^ *(tmp + 2) ^ *(resultTmp + 2) ^ *(tmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，则记录下该行的行数
                        diffStart = i;
                        outSideBreakFlag = YES;
                        break;
                    }
                }
                if (outSideBreakFlag) {
                    break;
                }
            }
            NSUInteger resultEnd = 0;
            // 从尾开始逐行遍历像素矩阵，找出不一样的行
            for (i = height, resultEnd = [resultImageData length] / bytesPerRow; i >= 0; i--, resultEnd--) {
                UInt8 *tmp;// 记录该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                BOOL outSideBreakFlag = NO;
                for (j = 0; j < width; j++) {
                    tmp = buffer + i * bytesPerRow + width * 4;
                    resultTmp = resultBuffer + resultEnd * bytesPerRow + width * 4;
                    if (*tmp ^ *resultTmp ^ *(tmp + 1) ^ *(resultTmp + 1) ^ *(tmp + 2) ^ *(resultTmp + 2) ^ *(tmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，则记录下该行的行数
                        diffEnd = i;
                        diffResultEnd = resultEnd;
                        outSideBreakFlag = YES;
                        break;
                    }
                }
                if (outSideBreakFlag) {
                    break;
                }
            }
            UInt8 *resultTmp = NULL;
            NSUInteger searchLength = (diffEnd - diffStart) * 10 / 100;// 保证有10%的重合率
            NSUInteger searchStart = diffResultEnd - searchLength;
            NSUInteger searchSamePercent = 0;// 重合率
            NSUInteger searchEndLinsNum = 0;
            // 从结果图片的第searchStart行开始找searchLength长度
            // 从目标图片的第diffStart行开始找，如果有不一样的就直接结束开始找下一行，如果找到searchLength的长度都一样，则匹配成功，直到匹配到diffEnd为止
            NSUInteger IResult = searchStart;// 结果图片的查找开始行
            for (i = diffStart; i < diffEnd; i++) {
                UInt8 *resultTmp;// 记录结果图像该行像素值
                UInt8 *tmp;// 记录该行像素值
                NSUInteger outSideBreakFlag = 0;// 0：初始化状态，1：异步率大于5%，2：同步率大于95%
                NSUInteger synchronize = 0;// 同步率大于95%即认为相同
                NSUInteger asynchronize = 0;// 异步率大于5%则停止遍历该行
                for (j = 0; j < width; j++) {
                    resultTmp = resultBuffer + IResult * bytesPerRow + width * 4;
                    tmp = buffer + i * bytesPerRow + width * 4;
                    if (*tmp ^ *resultTmp ^ *(tmp + 1) ^ *(resultTmp + 1) ^ *(tmp + 2) ^ *(resultTmp + 2) ^ *(tmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，异步率+1
                        asynchronize++;
                        if (asynchronize > width * 5 / 100) {
                            outSideBreakFlag = 1;
                            break;
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
                    IResult = searchStart;// 结果图片的查找开始行重置
                    searchSamePercent = 0;// 同步率重置
                } else if (outSideBreakFlag == 2) {
                    // 该行相同
                    searchSamePercent++;
                    IResult++;// 结果图片的查找行+1
                    if (searchSamePercent >= searchLength) {
                        searchEndLinsNum = i;// 记录结束的行数
                        break;
                    }
                }
            }
            
            imageAddCount = imageAddCount + diffEnd - searchEndLinsNum;// 两个图片的不同行末尾与相同查找行末尾相减得到多出来的行
            CFMutableDataRef resultMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, resultCFData);
            UInt8 *startByte = buffer + searchEndLinsNum * bytesPerRow + width * 4;// 新加上去的图片buffer的首地址
            CFRange deleteRange = CFRangeMake(IResult * bytesPerRow, CFDataGetLength(resultCFData) - IResult * bytesPerRow);// 需要替换的结果图片的尾部
            CFDataReplaceBytes(resultMutableDataRef, deleteRange, startByte, (height - searchEndLinsNum) * bytesPerRow);// 替换结果图片尾部为目标图片
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

- (void)mixImageWithArray1:(NSArray *)screenArray complete:(void (^)(UIImage *mixImage))complete {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableData *resultImageData = [[NSMutableData alloc] init];
        for (UIImage *currentImage in screenArray) {
            CGImageRef imgref = currentImage.CGImage;
            size_t width = CGImageGetWidth(imgref);
            size_t height = CGImageGetHeight(imgref);
            size_t bitsPerComponent = CGImageGetBitsPerComponent(imgref);//图片每个颜色的bits
            size_t bitsPerPixel = CGImageGetBitsPerPixel(imgref);//每一个像素占用的bits
            size_t bytesPerRow = CGImageGetBytesPerRow(imgref);//每一行占用多少bytes 注意是bytes不是bits  1byte ＝ 8bit

            CGColorSpaceRef colorSpace = CGImageGetColorSpace(imgref);
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imgref);

            bool shouldInterpolate = CGImageGetShouldInterpolate(imgref);

            CGColorRenderingIntent intent = CGImageGetRenderingIntent(imgref);

            CGDataProviderRef dataProvider = CGImageGetDataProvider(imgref);

            CFDataRef data = CGDataProviderCopyData(dataProvider);
            CFDataRef resultCFData = CFBridgingRetain(resultImageData);
            UInt8 *buffer = (UInt8*)CFDataGetBytePtr(data);//Returns a read-only pointer to the bytes of a CFData object.// 首地址
            UInt8 *resultBuffer = (UInt8*)CFDataGetBytePtr(resultCFData);//Returns a read-only pointer to the bytes of a CFData object.// 首地址
            NSUInteger  x, y;
            // 像素矩阵遍历，改变成自己需要的值
            for (y = 0; y < height ; y++) {
                NSData *cacheData = [NSData dataWithBytes:buffer + y * width * 4 length:width * 4];
                NSData *resultData = [NSData dataWithBytes:resultBuffer + y * width * 4 length:width *4];
                
                for (x = 0; x < width; x++) {
                    UInt8 *tmp;
                    tmp = buffer + y * bytesPerRow + x * 4;
                    *tmp = *tmp;
                    if ((int)*tmp == 255 && (int)*(tmp + 1) == 220 && (int)*(tmp + 2) == 1) {
                        *(tmp) = 255;
                        *(tmp + 1) = 255;
                        *(tmp + 2) = 255;
                    }
                    if ((int)*tmp == 251 && (int)*(tmp + 1) == 218 && (int)*(tmp + 2) == 1) {
                        *(tmp) = 255;
                        *(tmp + 1) = 255;
                        *(tmp + 2) = 255;
                    }
                }
            }

            CFDataRef effectedData = CFDataCreate(NULL, buffer, CFDataGetLength(data));

            CGDataProviderRef effectedDataProvider = CGDataProviderCreateWithCFData(effectedData);
            // 生成一张新的位图
            CGImageRef effectedCgImage = CGImageCreate(
                                                       width, height,
                                                       bitsPerComponent, bitsPerPixel, bytesPerRow,
                                                       colorSpace, bitmapInfo, effectedDataProvider,
                                                       NULL, shouldInterpolate, intent);
            //        CGContextRef effectedCgImage1 = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, bitmapInfo);
            //        CGImageRef effectedCgImage = CGBitmapContextCreateImage(effectedCgImage1);

            UIImage *effectedImage = [[UIImage alloc] initWithCGImage:effectedCgImage];

            CGImageRelease(effectedCgImage);

            CFRelease(effectedDataProvider);

            CFRelease(effectedData);

            CFRelease(data);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (complete) {
                    complete(effectedImage);
                }
            });
        }
    });
}

- (void)mixImageWithArray2:(NSArray *)screenArray complete:(void (^)(UIImage *mixImage))complete {
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
                    currentTmp = currentBuffer + i * bytesPerRow + width * 4;
                    resultTmp = resultBuffer + i * bytesPerRow + width * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，则记录下该行的行数
                        diffCurrentStart = i;
                        diffResultStart = i;
                        outSideBreakFlag = YES;
                        break;
                    }
                }
                if (outSideBreakFlag == YES) {
                    CFRange range1 = CFRangeMake(diffCurrentStart * bytesPerRow, height * bytesPerRow - diffCurrentStart * bytesPerRow);
                    CFRange range2 = CFRangeMake(diffResultStart * bytesPerRow, [resultImageData length] - diffResultStart * bytesPerRow);
                    UIImage *currentImage1 = [self createNewImage:currentTmp imageArray:screenArray data:currentData range:range1];
                    UIImage *resultImage1 = [self createNewImage:resultTmp imageArray:screenArray data:resultCFData range:range2];
                    NSLog(@"resultImage");
                    break;
                }
            }
            
            // 从尾开始逐行遍历像素矩阵，找出不一样的行
            for (i = height, diffResultEnd = [resultImageData length] / bytesPerRow; i > 0; i--, diffResultEnd--) {
                UInt8 *currentTmp;// 记录该行像素值
                UInt8 *resultTmp;// 记录结果图像该行像素值
                BOOL outSideBreakFlag = NO;
                for (j = 0; j < width; j++) {
                    currentTmp = currentBuffer + i * bytesPerRow + width * 4;
                    resultTmp = resultBuffer + diffResultEnd * bytesPerRow + width * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，则记录下该行的行数
                        diffCurrentEnd = i;
                        diffResultEnd = diffResultEnd;
                        outSideBreakFlag = YES;
                        break;
                    }
                }
                if (outSideBreakFlag) {
                    CFRange range1 = CFRangeMake(0, diffCurrentEnd * bytesPerRow);
                    CFRange range2 = CFRangeMake(0, diffResultEnd * bytesPerRow);
                    UIImage *currentImage1 = [self createNewImage:currentTmp imageArray:screenArray data:currentData range:range1];
                    UIImage *resultImage1 = [self createNewImage:resultTmp imageArray:screenArray data:resultCFData range:range2];
                    NSLog(@"resultImage");
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
                NSUInteger unusual = 0;// 用来记录异常值的临时变量，如果已经有匹配成功的行，但是有可能偶尔遇到一个匹配不成功的行，那么就+1，直到其值大于searchLength的10%才认为不相等
                
                
//                CFMutableDataRef currentMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, currentData);
//                CFRange deleteRange1 = CFRangeMake(0, i * bytesPerRow);
//                CFDataDeleteBytes(currentMutableDataRef, deleteRange1);
//                CFRange deleteRange2 = CFRangeMake(diffCurrentEnd * bytesPerRow, height * bytesPerRow - diffCurrentEnd * bytesPerRow);
//                CFDataDeleteBytes(currentMutableDataRef, deleteRange2);
//                UIImage *currentImage3 = [self createNewImage:currentTmp imageArray:screenArray data:currentMutableDataRef range:CFRangeMake(0, 0)];
//
//                CFMutableDataRef resultMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, resultCFData);
//                CFRange deleteRange3 = CFRangeMake(0, searchResultStart * bytesPerRow);
//                CFDataDeleteBytes(resultMutableDataRef, deleteRange3);
//                CFRange deleteRange4 = CFRangeMake(searchResultStart * bytesPerRow, [resultImageData length] - diffResultEnd * bytesPerRow);
//                CFDataDeleteBytes(resultMutableDataRef, deleteRange4);
//                UIImage *currentImage4 = [self createNewImage:currentTmp imageArray:screenArray data:resultMutableDataRef range:CFRangeMake(0, 0)];
//
//
//                CFRange range1 = CFRangeMake(i * bytesPerRow, height * bytesPerRow - i * bytesPerRow);
//                CFRange range2 = CFRangeMake(searchResultStart * bytesPerRow, [resultImageData length] - searchResultStart * bytesPerRow);
//                UIImage *currentImage1 = [self createNewImage:currentTmp imageArray:screenArray data:currentData range:range1];
//                UIImage *resultImage1 = [self createNewImage:resultTmp imageArray:screenArray data:resultCFData range:range2];
//
//                CFRange range3 = CFRangeMake(0, i * bytesPerRow);
//                CFRange range4 = CFRangeMake(0, searchResultStart * bytesPerRow);
//                UIImage *currentImage2 = [self createNewImage:currentTmp imageArray:screenArray data:currentData range:range1];
//                UIImage *resultImage2 = [self createNewImage:resultTmp imageArray:screenArray data:resultCFData range:range2];
//
//                NSLog(@"resultImage");
                
                
                for (j = 0; j < width; j++) {
                    currentTmp = currentBuffer + i * bytesPerRow + width * 4;
                    resultTmp = resultBuffer + searchResultStart * bytesPerRow + width * 4;
                    if (*currentTmp ^ *resultTmp ^ *(currentTmp + 1) ^ *(resultTmp + 1) ^ *(currentTmp + 2) ^ *(resultTmp + 2) ^ *(currentTmp + 3) ^ *(resultTmp + 3)) {
                        // 异或，如果不相同，异步率+1
                        asynchronize++;
                        if (asynchronize > width * 5 / 100) {
                            outSideBreakFlag = 1;
                            if (searchResultStart != diffResultEnd - searchLength) {
                                // searchResultStart不等于初始值，说明其已经有相同的行，但是有可能偶尔遇到一个不相同的行，在这里做一个记录
                                outSideBreakFlag = 3;
                            }
                            break;
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
                } else if (outSideBreakFlag == 3) {
                    // 如果异常行连续值大于了searchLength的10%才认为不相等
                    unusual++;
                    if (unusual > searchLength * 10 / 100) {
                        // 该行不同
                        searchResultStart = diffResultEnd - searchLength;// 结果图片的查找开始行重置
                        searchSamePercent = 0;// 重合率重置
                    } else {
                        // 该行相同
                        searchSamePercent++;// 重合率+1
                        searchResultStart++;// 结果图片的查找行+1
                        if (searchSamePercent >= searchLength) {
                            searchCurrentEnd = i;// 记录结束的行数
                            break;
                        }
                    }
                }
            }
            
            imageAddCount = imageAddCount + diffCurrentEnd - searchCurrentEnd;// 每次遍历多出来的行数
            CFMutableDataRef resultMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, resultCFData);
            UInt8 *startByte = currentBuffer + searchCurrentEnd * bytesPerRow + width * 4;// 新加上去的图片buffer的首地址
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

- (UIImage *)createNewImage:(UInt8 *)startByte imageArray:(NSArray *)screenArray data:(CFDataRef)resultCFData range:(CFRange)deleteRange {
    
    CFMutableDataRef resultMutableDataRef = CFDataCreateMutableCopy(CFAllocatorGetDefault(), 0, resultCFData);
    CFDataDeleteBytes(resultMutableDataRef, deleteRange);
    
    NSData *resultImageData = (__bridge_transfer NSData *)resultMutableDataRef;
    
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
    
    return effectedImage;
}

@end
