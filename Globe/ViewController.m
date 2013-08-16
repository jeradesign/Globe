//
//  ViewController.m
//  Globe
//
//  Created by John Brewer on 1/19/13.
//  Copyright (c) 2013 Jera Design LLC. All rights reserved.
//

#import "ViewController.h"
#import "GlobeView.h"
#import "drawglobe.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

@interface ViewController ()

@property (strong, nonatomic) EAGLContext *context;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GlobeView *view = (GlobeView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [view setupGL];
}

- (void)dealloc
{    
    GlobeView *view = (GlobeView *)self.view;
    [view tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        GlobeView *view = (GlobeView *)self.view;
        [view tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

@end
