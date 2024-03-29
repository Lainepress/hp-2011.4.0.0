/* include/HsOpenGL.h.  Generated from HsOpenGL.h.in by configure.  */
/* -----------------------------------------------------------------------------
 *
 * Module      :  C support for Graphics.Rendering.OpenGL
 * Copyright   :  (c) Sven Panne 2002-2005
 * License     :  BSD-style (see the file libraries/OpenGL/LICENSE)
 * 
 * Maintainer  :  sven.panne@aedion.de
 * Stability   :  provisional
 * Portability :  portable
 *
 * -------------------------------------------------------------------------- */

#ifndef HSOPENGL_H
#define HSOPENGL_H

/* Define to 1 if native OpenGL should be used on Mac OS X */
/* #undef USE_QUARTZ_OPENGL */

#if defined(_WIN32) || defined(__CYGWIN__)

/* for the prototype of wglGetProcAddress */
#include <windows.h>
#include <GL/glu.h>

#elif defined(USE_QUARTZ_OPENGL)

#include <OpenGL/glu.h>

#else

/* Hmmm, this seems to be necessary to get a prototype for glXGetProcAddressARB
   when Mesa is used. Strange... */
#ifndef GLX_GLXEXT_PROTOTYPES
#define GLX_GLXEXT_PROTOTYPES
#endif

#include <GL/glu.h>
#include <GL/glx.h>

#endif

extern void* hs_OpenGL_getProcAddress(char* procName);

#endif
