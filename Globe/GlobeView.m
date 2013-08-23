//
//  GlobeView.m
//  Globe
//
//  Created by John Brewer on 8/16/13.
//  Copyright (c) 2013 Jera Design LLC. All rights reserved.
//

#import "GlobeView.h"
#include "drawglobe.h"
#include "sun_position.h"

#define HORIZ_SWIPE_DRAG_MIN  12
#define VERT_SWIPE_DRAG_MAX    4

#define USE_DEPTH_BUFFER 0
#define USE_LIGHTING 1
#define DARK_SIDE_BRIGHTNESS 0.17

//#define RADIUS 160.0
//#define CENTER_X 160.0
//#define MAX_X 320.0
//static int CENTER_Y = 240.0;
//static int MAX_Y = 480.0;

#define FLICK_SPEED_THRESHOLD 200.0

#define DRAG_UNDECIDED 0
#define DRAG_HORIZONTAL 1
#define DRAG_VERTICAL 2

#define TO_DEGREES (180.0 / M_PI)
#define TO_RADIANS (M_PI / 180.0)

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

static bool reverse_rotation = NO;

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_LIGHT_POSITION,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    ATTRIB_TEX0,
    NUM_ATTRIBUTES
};

@implementation GlobeView {
    GLuint _program;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    GLKTextureInfo *_texture;
    GLuint _samplerLoc;

    double _tilt;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    float aspect = fabsf(self.bounds.size.width / self.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 modelViewMatrix;
    
    // Compute the model view matrix for the object rendered with ES2
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -3.0f);
    GLKMatrix4 rotationMatrix = GLKMatrix4MakeRotation(TO_RADIANS * _tilt, 1.0f, 0.0f, 0.0f);
    rotationMatrix = GLKMatrix4Rotate(rotationMatrix, TO_RADIANS * rotation, 0.0f, 1.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotationMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    GLKVector3 sunPosition = { 0.0, 0.0, 0.0 };
    sun_position(sunPosition.v);
    sunPosition = GLKMatrix4MultiplyAndProjectVector3(rotationMatrix, sunPosition);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniform3f(uniforms[UNIFORM_LIGHT_POSITION], sunPosition.v[0], sunPosition.v[1], sunPosition.v[2]);
    
    //    glDrawArrays(GL_TRIANGLES, 0, 36);
    glActiveTexture ( GL_TEXTURE0 );
    glBindTexture(GL_TEXTURE_2D, _texture.name);
    glUniform1i(_samplerLoc, 0);
    drawGlobeWithVertexArrays();
    
    GLenum error = glGetError();
    if (error) {
        NSLog(@"OpenGL error # %04x", error);
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)glkViewControllerUpdate:(GLKViewController *)controller
{
    rotation += rotation_inc;
    rotation = fmod(rotation, 360.0);
    if (rotation < 0) {
        rotation += 360.0;
    }
    _tilt += tilt_inc;
    _tilt = fmod(_tilt, 360.0);
    if (_tilt < 0) {
        _tilt += 360.0;
    }
    //    rotation += controller.timeSinceLastUpdate * 0.5f;
}

#pragma mark - Touch Event Handling

- (void)logMessage:(const char *)message withTouch:(UITouch *)touch {
    //  CGPoint location = [touch locationInView:self];
    //  NSLog(@"%s: %f, (%f, %f)", message, touch.timestamp, location.x, location.y);
}

- (double)reverseXIfNeeded:(double) x {
    if (reverse_rotation) {
        x = self.bounds.size.width - x;
    }
    return x;
}

- (BOOL)shouldReverse:(CGPoint) position {
    
    // don't do pole test if almost rightside up or upside down.
    if (_tilt <= 30.0 || _tilt >= 330.0) {
        return NO;
    }
    if (_tilt >= 150.0 && _tilt <= 210.0) {
        return YES;
    }
    
    BOOL northPoleVisible = sin(_tilt * TO_RADIANS) > 0;
    
    float CENTER_Y = self.bounds.size.height / 2;
    float RADIUS = self.bounds.size.width / 2;
    
    if (northPoleVisible) {
        double northPolePosition = -cos(_tilt * TO_RADIANS) * RADIUS + CENTER_Y;
        //    debugLabel.text = [NSString stringWithFormat:@"^ tilt: %-5.1f, nPP: %-5.1f, y: %-5.1f", tilt, northPolePosition, position.y];
        return position.y < northPolePosition;
    } else {
        double southPolePosition = cos(_tilt * TO_RADIANS) * RADIUS + CENTER_Y;
        //    debugLabel.text = [NSString stringWithFormat:@"V tilt: %-5.1f, sPP: %-5.1f, y: %-5.1f", tilt, southPolePosition, position.y];
        return position.y > southPolePosition;
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
    last_touch_time = touch.timestamp;
    last_touch_location = [touch locationInView:self];
    startTouchPosition = [touch locationInView:self];
    
    reverse_rotation = [self shouldReverse:startTouchPosition];
    
    rotation_inc = 0.0;
    starting_rotation = rotation;
    double x = startTouchPosition.x;
    x = [self reverseXIfNeeded:x];
    float CENTER_X = self.bounds.size.width / 2;
    starting_rotation_offset = [self rotationFromBase:CENTER_X toOffset:x];
    tilt_inc = 0.0;
    starting_tilt = _tilt;
    float CENTER_Y = self.bounds.size.height / 2;
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
    
    double x = currentTouchPosition.x;
    x = [self reverseXIfNeeded:x];
    float CENTER_X = self.bounds.size.width / 2;
    rotation = [self rotationFromBase:CENTER_X toOffset:x];
    rotation += starting_rotation - starting_rotation_offset;
    float CENTER_Y = self.bounds.size.height / 2;
    _tilt = [self rotationFromBase:CENTER_Y toOffset:currentTouchPosition.y];
    _tilt += starting_tilt - starting_tilt_offset;
    fmod(_tilt, 360.0);
    if(_tilt < 0) {
        _tilt += 360.0;
    }
//    debugLabel.text = [NSString stringWithFormat:@"tilt: %-5.1f", tilt];
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
        //    debugLabel.text = @"not flicked";
        //    NSLog(@"not flicked");
        return;
    }
    //  debugLabel.text = @"flicked";
    //  NSLog(@"flicked");
    double currentX = [touch locationInView:self].x;
    currentX = [self reverseXIfNeeded:currentX];
    double previousX = last_touch_location.x;
    previousX = [self reverseXIfNeeded:previousX];
    double deltaAngle = [self rotationFromBase:previousX toOffset:currentX];
    double deltaT = touch.timestamp - last_touch_time;
    if (deltaT <= 0.0) {
        deltaT = 1.0 / 60.0;
    }
    rotation_inc = (deltaAngle / deltaT) * (1.0 / 60.0);
    //  NSLog(@"deltaAngle = %f, deltaT = %f, rotation_inc = %f", deltaAngle, deltaT, rotation_inc);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    [self logMessage:__PRETTY_FUNCTION__ withTouch:touch];
}

- (double)rotationFromBase:(double)base toOffset:(double)offset {
    double numer = offset - base;
    float RADIUS = self.bounds.size.width / 2;
    if (numer > RADIUS) {
        numer = RADIUS;
    } else if (numer < -RADIUS) {
        numer = -RADIUS;
    }
    double result = asin(numer / RADIUS);
    result *= TO_DEGREES;
    if (isnan(result)) {
        NSLog(@"%s, isnan(%f), %f, %f", __PRETTY_FUNCTION__, result, base, offset);
        result = 0;
    }
    //  NSString *resultAsString = [NSString stringWithFormat:@"%f", result];
    //  [debugLabel setText:resultAsString];
    return result;
}

#pragma mark - OpenGL Setup/Teardown

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    //    glGenVertexArraysOES(1, &_vertexArray);
    //    glBindVertexArrayOES(_vertexArray);
    //
    //    glGenBuffers(1, &_vertexBuffer);
    //    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    //    glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertexData), gCubeVertexData, GL_STATIC_DRAW);
    //
    //
    //    glEnableVertexAttribArray(GLKVertexAttribPosition);
    //    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(0));
    //    glEnableVertexAttribArray(GLKVertexAttribNormal);
    //    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(12));
    //
    //    glBindVertexArrayOES(0);
    
    NSString *texturePath = [[NSBundle mainBundle] pathForResource:@"tinyworld4" ofType:@"png"];
    NSError *error;
    _texture = [GLKTextureLoader textureWithContentsOfFile:texturePath options:nil error:&error];
    if (error != nil) {
        NSLog(@"%@", error);
    }
    
    generateGlobeVertexArrays(ATTRIB_VERTEX, ATTRIB_NORMAL, ATTRIB_TEX0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    //    glDeleteBuffers(1, &_vertexBuffer);
    //    glDeleteVertexArraysOES(1, &_vertexArray);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
    _samplerLoc = glGetUniformLocation(_program, "s_texture");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
