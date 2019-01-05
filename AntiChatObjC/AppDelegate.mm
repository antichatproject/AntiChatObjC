//
//  AppDelegate.m
//  AntiChatObjC
//

#import "opencv2/opencv.hpp"
#import "AppDelegate.h"
#import "NSImage+OpenCV.h"

#define IMAGE_WIDTH 640
#define IMAGE_HEIGHT 320

@interface AppDelegate () {
  cv::VideoCapture _videoCapture;
  NSMutableArray *_images;
  int _msecPosition;
  int _deltaDiff;
  IBOutlet NSSlider *_deltaDiffSlider;
  IBOutlet NSTextField *_deltaDiffTextField;
  IBOutlet NSTextField *_positionTextField;
}

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSImageView *beforeImageView;
@property (weak) IBOutlet NSImageView *afterImageView;
@property (weak) IBOutlet NSImageView *resultImageView;

@end

@implementation AppDelegate

- (NSImage*)iplImageToNSImage:(IplImage*)iplImage {
      NSBitmapImageRep *bmp= [[NSBitmapImageRep alloc]
                                                          initWithBitmapDataPlanes:0
                                                          pixelsWide:iplImage->width
                                                          pixelsHigh:iplImage->height
                                                          bitsPerSample:iplImage->depth
                                                          samplesPerPixel:iplImage->nChannels
                                                          hasAlpha:NO isPlanar:NO
                                                          colorSpaceName:NSDeviceRGBColorSpace
                                                          bytesPerRow:iplImage->widthStep
                                                          bitsPerPixel:0];
      NSUInteger val[3]= {0, 0, 0};
      for(int x=0; x < iplImage->width; x++) {
            for(int y=0; y < iplImage->height; y++) {
                  CvScalar scal= cvGet2D(iplImage, y, x);
                  val[0]= scal.val[0];
                  val[1]= scal.val[1];
                  val[2]= scal.val[2];
                  [bmp setPixel:val atX:x y:y];
              }
        }
      return [[NSImage alloc] initWithData:[bmp TIFFRepresentation]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Insert code here to initialize your application
  NSString *path = [[NSBundle mainBundle] pathForResource:@"chat_MDalarm_20180403_044658" ofType:@"mkv"];
//  NSString *path = [[NSBundle mainBundle] pathForResource:@"chat_MDalarm_20180416_092815" ofType:@"mkv"];
  _videoCapture.open(cv::String(path.UTF8String));
//  _videoCapture.set(CV_CAP_PROP_POS_FRAMES, 0);
//  CvCapture* capture = cvCreateFileCapture(path.UTF8String);
//  cvSetCaptureProperty(capture, CV_CAP_PROP_POS_MSEC, 2000);
//  IplImage* frame = NULL;
//  frame = cvQueryFrame(capture);
  if (NO) {
    cv::Mat image;
    _images = [NSMutableArray array];
    while (_videoCapture.read(image)) {
      [_images addObject:[[NSImage alloc] initWithCVMat:image]];
    }
    NSLog(@"%ld", _images.count);
  }
  _deltaDiff = 50;
  _msecPosition = 0;
  [self updatePosition];
  [self updateDeltaDiff];
  [self updateImage];
}

- (void)updateImage {
  NSImage *nsimage = nil;
  NSImage *resultImage = nil;
  cv::Mat image1;
  cv::Mat image2;
  cv::Mat image3;
  bool hasImage1 = false;
  bool hasImage2 = false;
  bool hasImage3 = false;
  if (_videoCapture.set(CV_CAP_PROP_POS_MSEC, _msecPosition - _deltaDiff))
    hasImage1 = _videoCapture.read(image1);
  if (_videoCapture.set(CV_CAP_PROP_POS_MSEC, _msecPosition))
    hasImage2 = _videoCapture.read(image2);
  if (_videoCapture.set(CV_CAP_PROP_POS_MSEC, _msecPosition + _deltaDiff))
    hasImage3 = _videoCapture.read(image3);
  if (hasImage1) {
    nsimage = [[NSImage alloc] initWithCVMat:image1];
    self.beforeImageView.image = nsimage;
  }
  if (hasImage2) {
    nsimage = [[NSImage alloc] initWithCVMat:image2];
    self.imageView.image = nsimage;
  }
  if (hasImage3) {
    nsimage = [[NSImage alloc] initWithCVMat:image3];
    self.afterImageView.image = nsimage;
  }
  if (hasImage1 && hasImage2 && hasImage3) {
    cv::Mat grayImage1;
    cv::Mat grayImage2;
    cv::Mat grayImage3;
    cv::Mat diff12;
    cv::Mat diff23;
    cv::Mat result;
    cv::resize(image1, image1, cv::Size(IMAGE_WIDTH, IMAGE_HEIGHT));
    cv::cvtColor(image1, grayImage1, cv::COLOR_BGR2GRAY);
    cv::resize(image2, image2, cv::Size(IMAGE_WIDTH, IMAGE_HEIGHT));
    cv::cvtColor(image1, grayImage2, cv::COLOR_BGR2GRAY);
    cv::resize(image3, image3, cv::Size(IMAGE_WIDTH, IMAGE_HEIGHT));
    cv::cvtColor(image1, grayImage3, cv::COLOR_BGR2GRAY);
    cv::absdiff(image1, image2, diff12);
    cv::absdiff(image2, image3, diff23);
    cv::bitwise_and(diff12, diff23, result);
    cv::Mat grayResult;
    cv::cvtColor(result, grayResult, cv::COLOR_BGR2GRAY);
//    diff = cv2.adaptiveThreshold(diff,255,cv2.ADAPTIVE_THRESH_GAUSSIAN_C,\
//                                 cv2.THRESH_BINARY,21,2)
    cv::Mat grayThres;
//    cv::Mat thres;
    cv::adaptiveThreshold(grayResult, grayThres, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY, 21, 2);
    resultImage = [[NSImage alloc] initWithCVMat:grayThres];
    resultImage.size = nsimage.size;
  }
  if (resultImage) {
    self.resultImageView.image = resultImage;
  }
  NSLog(@"%d image %p", _msecPosition, resultImage);
}

- (void)updateDeltaDiff {
  _deltaDiffSlider.intValue = _deltaDiff;
  _deltaDiffTextField.stringValue = [NSString stringWithFormat:@"%d", _deltaDiff];
}

- (void)updatePosition {
//  _slider.intValue = _msecPosition;
  _positionTextField.stringValue = [NSString stringWithFormat:@"%d", _msecPosition];
}

#pragma mark - Actions

- (IBAction)timerSliderAction:(NSSlider *)sender {
  double frameCount = _videoCapture.get(CV_CAP_PROP_FRAME_COUNT);
  double fps = _videoCapture.get(CV_CAP_PROP_FPS);
  _msecPosition = frameCount * sender.doubleValue / fps * 1000;
  [self updateImage];
}

- (IBAction)deltaDiffSliderAction:(NSSlider *)sender {
  _deltaDiff = _deltaDiffSlider.intValue;
  [self updateDeltaDiff];
  [self updatePosition];
  [self updateImage];
}

@end
