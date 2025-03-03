#import "RNForceTouchHandler.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

#import <React/RCTConvert.h>

@interface RNForceTouchGestureRecognizer : UIGestureRecognizer

@property (nonatomic) CGFloat maxForce;
@property (nonatomic) CGFloat minForce;
@property (nonatomic) CGFloat force;
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL feedbackOnActivation;

- (id)initWithGestureHandler:(RNGestureHandler*)gestureHandler;

@end

@implementation RNForceTouchGestureRecognizer {
  __weak RNGestureHandler *_gestureHandler;
  UITouch *_firstTouch;
}

static const CGFloat defaultForce = 0;
static const CGFloat defaultRadius = 0;
static const CGFloat defaultMinForce = 0.2;
static const CGFloat defaultMaxForce = NAN;
static const BOOL defaultFeedbackOnActivation = NO;

- (id)initWithGestureHandler:(RNGestureHandler*)gestureHandler
{
  if ((self = [super initWithTarget:gestureHandler action:@selector(handleGesture:)])) {
    _gestureHandler = gestureHandler;
    _force = defaultForce;
    _radius = defaultRadius;
    _minForce = defaultMinForce;
    _maxForce = defaultMaxForce;
    _feedbackOnActivation = defaultFeedbackOnActivation;
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (_firstTouch) {
    // ignore rest of fingers
    return;
  }
  [super touchesBegan:touches withEvent:event];
  _radius = _firstTouch.majorRadius;
  _firstTouch = [touches anyObject];
  [self handleForceWithTouches:touches];
  self.state = UIGestureRecognizerStateBegan;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (![touches containsObject:_firstTouch]) {
    // Considered only the very first touch
    return;
  }
  [super touchesMoved:touches withEvent:event];
  
  [self handleForceWithTouches:touches];
  
  if ([self shouldFail]) {
    self.state = UIGestureRecognizerStateFailed;
    return;
  }
  
  if (self.state == UIGestureRecognizerStatePossible && [self shouldActivate]) {
    [self performFeedbackIfRequired];
    self.state = UIGestureRecognizerStateBegan;
  }
}

- (BOOL)shouldActivate {
  return (_force >= _minForce);
}

- (BOOL)shouldFail {
  return TEST_MAX_IF_NOT_NAN(_force, _maxForce);
}

- (void)performFeedbackIfRequired
{
#if !TARGET_OS_TV
  if (_feedbackOnActivation) {
    if (@available(iOS 10.0, *)) {
      [[[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleMedium)] impactOccurred];
    }
  }
#endif
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (![touches containsObject:_firstTouch]) {
    // Considered only the very first touch
    return;
  }
  [super touchesEnded:touches withEvent:event];
  if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
    self.state = UIGestureRecognizerStateEnded;
  } else {
    self.state = UIGestureRecognizerStateFailed;
  }
}

- (void)handleForceWithTouches:(NSSet<UITouch *> *)touches {
  _force = _firstTouch.force / _firstTouch.maximumPossibleForce;
}

- (void)reset {
  [super reset];
  _force = 0;
  _radius = 0;
  _firstTouch = NULL;
}

@end

@implementation RNForceTouchHandler

- (instancetype)initWithTag:(NSNumber *)tag
{
  if ((self = [super initWithTag:tag])) {
    _recognizer = [[RNForceTouchGestureRecognizer alloc] initWithGestureHandler:self];
  }
  return self;
}

- (void)resetConfig
{
  [super resetConfig];
  RNForceTouchGestureRecognizer *recognizer = (RNForceTouchGestureRecognizer *)_recognizer;
  
  recognizer.feedbackOnActivation = defaultFeedbackOnActivation;
  recognizer.maxForce = defaultMaxForce;
  recognizer.minForce = defaultMinForce;
}

- (void)configure:(NSDictionary *)config
{
  [super configure:config];
  RNForceTouchGestureRecognizer *recognizer = (RNForceTouchGestureRecognizer *)_recognizer;

  APPLY_FLOAT_PROP(maxForce);
  APPLY_FLOAT_PROP(minForce);

  id prop = config[@"feedbackOnActivation"];
  if (prop != nil) {
    recognizer.feedbackOnActivation = [RCTConvert BOOL:prop];
  }
}

- (RNGestureHandlerEventExtraData *)eventExtraData:(RNForceTouchGestureRecognizer *)recognizer
{
  return [RNGestureHandlerEventExtraData
          forForce: recognizer.force
          forPosition:[recognizer locationInView:recognizer.view]
          forRadius: recognizer.radius
          withAbsolutePosition:[recognizer locationInView:recognizer.view.window]
          withNumberOfTouches:recognizer.numberOfTouches];
}

@end

