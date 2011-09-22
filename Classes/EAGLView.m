//
//  EAGLView.m
//  Globe
//
//  Copyright Jera Design LLC 2009. All rights reserved.
//



#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"
#include "drawglobe.h"
#include "sun_position.h"

#define HORIZ_SWIPE_DRAG_MIN  12
#define VERT_SWIPE_DRAG_MAX    4

#define USE_DEPTH_BUFFER 0
#define USE_LIGHTING 1

#define RADIUS 160.0
#define CENTER_X 160.0
#define CENTER_Y 240.0
#define FLICK_SPEED_THRESHOLD 200.0

#define DRAG_UNDECIDED 0
#define DRAG_HORIZONTAL 1
#define DRAG_VERTICAL 2

static double rotation = INITIAL_ROTATION;
static double rotation_inc = 1;
static double tilt_inc = 0.0;

static double starting_rotation = 0.0;
static double starting_rotation_offset = 0.0;

static double starting_tilt = 0.0;
static double starting_tilt_offset = 0.0;

static NSTimeInterval last_touch_time;
static CGPoint last_touch_location;

static CGPoint startTouchPosition;

static int drag_direction;

// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) NSTimer *animationTimer;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;
- (void) initTexture;
- (double) rotationFromBase:(double) base toOffset:(double) offset;

@end


@implementation EAGLView

@synthesize context;
@synthesize animationTimer;
@synthesize debugLabel;


// You must implement this
+ (Class)layerClass {
  return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
  
  if ((self = [super initWithCoder:coder])) {
    // Get the layer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    if (!context || ![EAGLContext setCurrentContext:context]) {
      [self release];
      return nil;
    }
    
    tilt = INITIAL_TILT;
    
    animationInterval = 1.0 / 60.0;
    generateGlobeVertexArrays();
    [self initTexture];
  }
  return self;
}


- (void)drawView {
  
  rotation += rotation_inc;
  tilt += tilt_inc;
  
  [EAGLContext setCurrentContext:context];
  
  glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
  //	glViewport(0, 0, backingWidth, backingHeight);
  glViewport(0, 80, 320, 320);
  
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  
#if USE_LIGHTING
  glEnable(GL_LIGHTING);
#endif
  
  //  glFrustumf(<#GLfloat left#>, <#GLfloat right#>, <#GLfloat bottom#>, <#GLfloat top#>, <#GLfloat zNear#>, <#GLfloat zFar#>)
  glTranslatef(0.0, 0.0, -1.0);
  
  glRotatef((GLfloat) tilt, 1.0, 0.0, 0.0);
  glRotatef((GLfloat) rotation, 0.0, 1.0, 0.0);
  
#if USE_LIGHTING
  GLfloat white[] = { 1.0, 1.0, 1.0, 1.0 };
  
  GLfloat front[] = {0.0, 0.0, 10.0, 0.0};
  float sunPosition[] = { 0.0, 0.0, 0.0 };
  sun_position(sunPosition);
  front[0] = sunPosition[0];
  front[1] = sunPosition[1];
  front[2] = sunPosition[2];
  
  GLfloat lmodel_ambient[] = { 0.17, 0.17, 0.17, 1.0 };
  glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lmodel_ambient);
  
  glEnable(GL_LIGHT0);
  glLightfv(GL_LIGHT0, GL_DIFFUSE, white);
  glLightfv(GL_LIGHT0, GL_POSITION, front);
  //  glLightfv(GL_LIGHT0, GL_SPECULAR, white);
  
  //  glEnable(GL_LIGHT1);
  //  glLightfv(GL_LIGHT1, GL_DIFFUSE, green);
  //  glLightfv(GL_LIGHT1, GL_POSITION, left);
  //  
  //  glEnable(GL_LIGHT2);
  //  glLightfv(GL_LIGHT2, GL_DIFFUSE, blue);
  //  glLightfv(GL_LIGHT2, GL_POSITION, right);
  //  
  //  glEnable(GL_LIGHT3);
  //  glLightfv(GL_LIGHT3, GL_DIFFUSE, orange);
  //  glLightfv(GL_LIGHT3, GL_POSITION, back);
  //
  //  glEnable(GL_LIGHT4);
  //  glLightfv(GL_LIGHT4, GL_AMBIENT, red);
  //  glLightfv(GL_LIGHT4, GL_POSITION, front);
#endif
  
  glEnable(GL_TEXTURE_2D);
  //  glEnable(GL_DEPTH_TEST);
  glClearColor(0.f, 0.f, 0.f, 0.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  
  drawGlobeWithVertexArrays(spriteTexture);
  
  glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
  [context presentRenderbuffer:GL_RENDERBUFFER_OES];
  GLenum error = glGetError();
  if (error) {
    NSLog(@"OpenGL error # %04x", error);
  }
}


- (void)layoutSubviews {
  [EAGLContext setCurrentContext:context];
  [self destroyFramebuffer];
  [self createFramebuffer];
  [self drawView];
}


- (BOOL)createFramebuffer {
  
  glGenFramebuffersOES(1, &viewFramebuffer);
  glGenRenderbuffersOES(1, &viewRenderbuffer);
  
  glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
  glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
  [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
  glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
  
  glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
  glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
  
  if (USE_DEPTH_BUFFER) {
    glGenRenderbuffersOES(1, &depthRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
  }
  
  if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
    NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
    return NO;
  }
  
  return YES;
}


- (void)destroyFramebuffer {
  
  glDeleteFramebuffersOES(1, &viewFramebuffer);
  viewFramebuffer = 0;
  glDeleteRenderbuffersOES(1, &viewRenderbuffer);
  viewRenderbuffer = 0;
  
  if(depthRenderbuffer) {
    glDeleteRenderbuffersOES(1, &depthRenderbuffer);
    depthRenderbuffer = 0;
  }
}

#pragma mark - Animation

- (void)startAnimation {
  self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation {
  self.animationTimer = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer {
  [animationTimer invalidate];
  animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
  
  animationInterval = interval;
  if (animationTimer) {
    [self stopAnimation];
    [self startAnimation];
  }
}

- (NSTimeInterval)animationInterval {
  return animationInterval;
}

#pragma mark - Touch Event Handling

- (void)logMessage:(const char *)message withTouch:(UITouch *)touch {
//  CGPoint location = [touch locationInView:self];
//  NSLog(@"%s: %f, (%f, %f)", message, touch.timestamp, location.x, location.y);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  UITouch *touch = [touches anyObject];
  [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
  last_touch_time = touch.timestamp;
  last_touch_location = [touch locationInView:self];
  startTouchPosition = [touch locationInView:self];
  rotation_inc = 0.0;
  starting_rotation = rotation;
  starting_rotation_offset = [self rotationFromBase:CENTER_X toOffset:startTouchPosition.x];
  tilt_inc = 0.0;
  starting_tilt = tilt;
  starting_tilt_offset = [self rotationFromBase:CENTER_Y toOffset:startTouchPosition.y];
  drag_direction = DRAG_UNDECIDED;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  UITouch *touch = touches.anyObject;
  [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
  last_touch_time = touch.timestamp;
  last_touch_location = [touch locationInView:self];
  CGPoint currentTouchPosition = [touch locationInView:self];
  rotation = [self rotationFromBase:CENTER_X toOffset:currentTouchPosition.x];
  rotation += starting_rotation - starting_rotation_offset;
  tilt = [self rotationFromBase:CENTER_Y toOffset:currentTouchPosition.y];
  tilt += starting_tilt - starting_tilt_offset;
}

- (double)speedForTouch:(UITouch *)touch {
  CGPoint endPoint = [touch locationInView:self];
  CGPoint startPoint = last_touch_location;
  double diffX = endPoint.x - startPoint.x;
  double diffY = endPoint.y - startPoint.y;
  double dist = sqrt(diffX * diffX + diffY * diffY);
  double deltaT = touch.timestamp - last_touch_time;
  double speed = dist / deltaT;
  
//  NSLog(@"speed = %f", speed);
  
  return speed; // experiment with best value
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
  UITouch *touch = [touches anyObject];
  [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
  double speed = [self speedForTouch:touch];
  if(speed < FLICK_SPEED_THRESHOLD) {
    debugLabel.text = @"not flicked";
//    NSLog(@"not flicked");
    return;
  }
  debugLabel.text = @"flicked";
//  NSLog(@"flicked");
  double currentX = [touch locationInView:self].x;
  double previousX = last_touch_location.x;
  double deltaAngle = [self rotationFromBase:previousX toOffset:currentX];
  double deltaT = touch.timestamp - last_touch_time;
  rotation_inc = (deltaAngle / deltaT) * animationInterval;
//  NSLog(@"deltaAngle = %f, deltaT = %f, rotation_inc = %f", deltaAngle, deltaT, rotation_inc);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  UITouch *touch = [touches anyObject];
  [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
}

- (double)rotationFromBase:(double)base toOffset:(double)offset {
  double numer = offset - base;
  if (numer > RADIUS) {
    numer = RADIUS;
  } else if (numer < -RADIUS) {
    numer = -RADIUS;
  }
  double result = asin(numer / RADIUS);
  result *= 180.0 / M_PI;
  if (isnan(result)) {
    NSLog(@"%s, isnan(%f), %f, %f", __PRETTY_FUNCTION__, result, base, offset);
    result = 0;
  }
  NSString *resultAsString = [NSString stringWithFormat:@"%f", result];
  [debugLabel setText:resultAsString];
  return result;
}

#pragma mark - Lifecycle

- (void)initTexture
{
  CGImageRef spriteImage;
  CGContextRef spriteContext;
  GLubyte *spriteData;
  size_t	width, height;
  
  // Creates a Core Graphics image from an image file
  spriteImage = [UIImage imageNamed:@"tinyworld4.png"].CGImage;
  // Get the width and height of the image
  width = CGImageGetWidth(spriteImage);
  height = CGImageGetHeight(spriteImage);
  // Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
  // you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
  
  if(spriteImage) {
    // Allocated memory needed for the bitmap context
    spriteData = (GLubyte *) malloc(width * height * 4);
    // Uses the bitmatp creation function provided by the Core Graphics framework. 
    spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    // After you create the context, you can draw the sprite image to the context.
    CGContextDrawImage(spriteContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), spriteImage);
    // You don't need the context at this point, so you need to release it to avoid memory leaks.
    CGContextRelease(spriteContext);
    
    // Use OpenGL ES to generate a name for the texture.
    glGenTextures(1, &spriteTexture);
    // Bind the texture name. 
    glBindTexture(GL_TEXTURE_2D, spriteTexture);
    // Speidfy a 2D texture image, provideing the a pointer to the image data in memory
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    // Release the image data
    free(spriteData);
    
    // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    // Enable use of the texture
    glEnable(GL_TEXTURE_2D);
    // Set a blending function to use
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    // Enable blending
    glEnable(GL_BLEND);
  }
}

- (void)dealloc {
  
  [self stopAnimation];
  
  if ([EAGLContext currentContext] == context) {
    [EAGLContext setCurrentContext:nil];
  }
  
  [context release];	
  [super dealloc];
}

@end
