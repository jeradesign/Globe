//
//  Shader.fsh
//  Globe
//
//  Created by John Brewer on 1/19/13.
//  Copyright (c) 2013 Jera Design LLC. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
