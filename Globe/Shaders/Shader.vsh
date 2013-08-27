//
//  Shader.vsh
//  Globe
//
//  Created by John Brewer on 1/19/13.
//  Copyright (c) 2013 Jera Design LLC. All rights reserved.
//

const float SUNNY_SIDE_MIN = 0.60;
const float DARK_SIDE = 0.1;
const float TWILIGHT_END_COS = -0.31; // cos of end of twilight zone (108 degrees)

attribute vec4 position;
attribute vec3 normal;
attribute vec2 a_texCoord;

varying lowp vec2 v_texCoord;
varying lowp float nDotVP;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;
uniform vec3 lightPosition;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
//    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    
    nDotVP = dot(eyeNormal, normalize(lightPosition));
    if (nDotVP > 0.0) {
        // scale sunny side from 1.0 (noon) to SUNNY_SIDE_MIN (sunset)
        nDotVP = SUNNY_SIDE_MIN * nDotVP + SUNNY_SIDE_MIN;
    } else if (nDotVP > - 0.3) {
        // scale twilight zone from SUNNY_SIDE_MIN (sunset) to DARK_SIDE (post-twilight)
        nDotVP =  SUNNY_SIDE_MIN - nDotVP * ((SUNNY_SIDE_MIN - DARK_SIDE) / TWILIGHT_END_COS);
    } else {
        nDotVP = DARK_SIDE;
    }

    gl_Position = modelViewProjectionMatrix * position;
    v_texCoord = a_texCoord;
}
