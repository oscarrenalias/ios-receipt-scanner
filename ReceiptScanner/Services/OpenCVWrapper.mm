#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>

@implementation OpenCVWrapper

+ (UIImage *)enhanceDocument:(UIImage *)image {
    cv::Mat cvImage;
    UIImageToMat(image, cvImage);

    // Convert to grayscale
    cv::Mat gray;
    cv::cvtColor(cvImage, gray, cv::COLOR_BGR2GRAY);

    // Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE();
    clahe->setClipLimit(2.0);
    cv::Mat claheResult;
    clahe->apply(gray, claheResult);

    // Adaptive thresholding to binarize
    cv::Mat thresh;
    cv::adaptiveThreshold(claheResult, thresh, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY, 15, 15);

    // Morphological opening to remove small blemishes
    cv::Mat morph;
    cv::morphologyEx(thresh, morph, cv::MORPH_OPEN, cv::Mat::ones(2, 2, CV_8U));

    // Convert back to UIImage
    UIImage *result = MatToUIImage(morph);
    return result;
}

@end
