/*
 *  ofxQTKitMoviePlayer example
 *
 * Created by James George, http://www.jamesgeorge.org
 * over a long period of time for a few different projects in collaboration with
 * FlightPhase http://www.flightphase.com 
 * and the rockwell group lab http://lab.rockwellgroup.com
 *
 **********************************************************
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * ----------------------
 * 
 * ofxQTKitVideoPlayer provides QTKit/CoreVideo accelerated movie playback
 * for openFrameworks on OS X
 * 
 * This class replaces almost all of the functionality of ofVideoPlayer on OS X
 * and uses the modern QTKit and CoreVideo libraries for playback
 *
 * Special Thanks to Marek Bereza for his initial QTKitVideoTexture
 * http://www.mrkbrz.com/
 *
 * Thanks to Anton Marini for help wrangling buffer contexts
 * http://vade.info/ 
 */

#import "QTKitMovieRenderer.h"

//secret methods!
@interface QTMovie (QTFrom763)
- (QTTime)frameStartTime: (QTTime)atTime;
- (QTTime)frameEndTime: (QTTime)atTime;
- (QTTime)keyframeStartTime:(QTTime)atTime;
@end

struct OpenGLTextureCoordinates
{
    GLfloat topLeft[2];
    GLfloat topRight[2];
    GLfloat bottomRight[2];
    GLfloat bottomLeft[2];
};

typedef struct OpenGLTextureCoordinates OpenGLTextureCoordinates;

@implementation QTKitMovieRenderer
@synthesize movieSize;
@synthesize useTexture;
@synthesize usePixels;
@synthesize frameCount;

- (BOOL) loadMovie:(NSString*)moviePath allowTexture:(BOOL)doUseTexture allowPixels:(BOOL)doUsePixels
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:moviePath])
    {
		NSLog(@"No movie file found at %@", moviePath);
		return NO;
	}
	
	//create visual context
	useTexture = doUseTexture;
	usePixels = doUsePixels;
	
	NSError* error;
	NSMutableDictionary* movieAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 [NSURL fileURLWithPath:[moviePath stringByStandardizingPath]], QTMovieURLAttribute,
									 [NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
									 nil];
	
	//opt into Quicktime X
	//this will give some speed up for texture-only rendering on 10.6 machines
	//but sometimes will slow it down alot!
//	#ifdef MAC_OS_X_VERSION_10_6
//	if(self.useTexture && !self.usePixels){
//		[movieAttributes setObject:[NSNumber numberWithBool:YES] forKey:QTMovieOpenForPlaybackAttribute];
//	}
//	#endif
	
	_movie = [[QTMovie alloc] initWithAttributes:movieAttributes 
										   error: &error];
	
	if(error || _movie == NULL){
		NSLog(@"Error Loading Movie: %@", error);
		return NO;
	}

	movieSize = [[_movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
	NSLog(@"movie size %f %f", movieSize.width, movieSize.height);
	
	movieDuration = [_movie duration];

	if ([_movie respondsToSelector: @selector(frameEndTime:)]) {
		// Only on QT 7.6.3
		QTTime	qtStep	= (QTTime)[_movie frameEndTime: QTMakeTime(0, _movie.duration.timeScale)];
		frameStep = qtStep.timeValue;
	}
	
	frameCount = movieDuration.timeValue / frameStep;
	NSLog(@" movie has %d frames ", frameCount);
	
	
	//if we are using pixels, make the visual context
	//a pixel buffer context with ARGB textures
	if(self.usePixels){
		NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
											   //if we have a texture, make the pixel buffer OpenGL compatible
											   [NSNumber numberWithBool:self.useTexture], (NSString*)kCVPixelBufferOpenGLCompatibilityKey, 
											   //in general this shouldn't be forced. but in order to ensure we get good pixels use this one
											   [NSNumber numberWithInt: kCVPixelFormatType_32ARGB], (NSString*)kCVPixelBufferPixelFormatTypeKey, 
											   //specifying width and height can't hurt since we know
											nil];
		
		NSMutableDictionary *ctxAttributes = [NSMutableDictionary dictionaryWithObject:pixelBufferAttributes 
																				forKey:(NSString*)kQTVisualContextPixelBufferAttributesKey];
		
		OSStatus err = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)ctxAttributes, &_visualContext);
		if(err){
			NSLog(@"error %i creating OpenPixelBufferContext", err);
			return NO;
		}
		
		// if we also have a texture, create a texture cache for it
		if(self.useTexture){
			//create a texture cache			
			err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, 
											 CGLGetCurrentContext(), CGLGetPixelFormat(CGLGetCurrentContext()), 
											 (CFDictionaryRef)ctxAttributes, &_textureCache);
			if(err){
				NSLog(@"error %i creating CVOpenGLTextureCacheCreate", err);
				return NO;
			}
		}
	}
	//if we are using a texture, just create an OpenGL visual context and call it a day
	else if(self.useTexture){
		OSStatus err = QTOpenGLTextureContextCreate(kCFAllocatorDefault,
													CGLGetCurrentContext(), CGLGetPixelFormat(CGLGetCurrentContext()),
													(CFDictionaryRef)NULL, &_visualContext);	
		if(err){
			NSLog(@"error %i creating QTOpenGLTextureContextCreate", err);
			return NO;
		}
	}
	else {
		NSLog(@"Error - QTKitMovieRenderer - Must specify either Pixels or Texture as rendering strategy");
		return NO;
	}
	
	[_movie setVisualContext:_visualContext];
	
	self.volume = 1.0;
	self.loops = YES;
	
	return YES;
}

- (void) dealloc
{

	if(_latestTextureFrame != NULL){
		CVOpenGLTextureRelease(_latestTextureFrame);
		_latestTextureFrame = NULL;
	}
	
	if(_latestPixelFrame != NULL){
		CVPixelBufferRelease(_latestPixelFrame);
		_latestPixelFrame = NULL;
	}
	
	if(_movie != NULL){
		[_movie release];
		_movie = NULL;
	}
	
	if(_visualContext != NULL){
		QTVisualContextRelease(_visualContext);
		_visualContext = NULL;
	}
	
	if(_textureCache != NULL){
		CVOpenGLTextureCacheRelease(_textureCache);
		_textureCache = NULL;
	}
	

	[super dealloc];
}

//JG Note, in the OF wrapper this does not get used since we have a modified ofTexture taht we use to draw
//this is here in case you want to use this renderer outside of openFrameworks
- (void) draw:(NSRect)drawRect
{   
	
	if(!self.useTexture || _latestTextureFrame == NULL){
		return;
	}
	
	OpenGLTextureCoordinates texCoords;	
	
	CVOpenGLTextureGetCleanTexCoords(_latestTextureFrame, 
									 texCoords.bottomLeft, 
									 texCoords.bottomRight, 
									 texCoords.topRight, 
									 texCoords.topLeft);        
	
	[self bindTexture];
	
	glBegin(GL_QUADS);
	
	glTexCoord2fv(texCoords.topLeft);
	glVertex2f(NSMinX(drawRect), NSMinY(drawRect));
	
	glTexCoord2fv(texCoords.topRight);
	glVertex2f(NSMaxX(drawRect), NSMinY(drawRect));
	
	glTexCoord2fv(texCoords.bottomRight);
	glVertex2f(NSMaxX(drawRect), NSMaxY(drawRect));
	
	glTexCoord2fv(texCoords.bottomLeft);
	glVertex2f(NSMinX(drawRect), NSMaxY(drawRect));
	
	glEnd();
	
	[self unbindTexture];
	
}


- (BOOL) update
{    
	
    if (_visualContext == NULL || !QTVisualContextIsNewImageAvailable(_visualContext, NULL)){
		return NO;
	}
	QTVisualContextTask(_visualContext);	
	if(self.usePixels){
		if(_latestPixelFrame != NULL){
			CVPixelBufferRelease(_latestPixelFrame);
			_latestPixelFrame = NULL;
		}
		
		OSStatus error = QTVisualContextCopyImageForTime(_visualContext, NULL, NULL, &_latestPixelFrame);	
		//In general this shouldn't happen, but just in case...
		if (error != noErr) {
			CVPixelBufferRelease(_latestPixelFrame);
			return NO;
		}
		
		//if we are using a texture, create one from the texture cache
		if(self.useTexture){
			if(_latestTextureFrame != NULL){
				CVOpenGLTextureRelease(_latestTextureFrame);
				_latestTextureFrame = NULL;
				CVOpenGLTextureCacheFlush(_textureCache, 0);	
			}
			
			OSErr err = CVOpenGLTextureCacheCreateTextureFromImage(NULL, _textureCache, _latestPixelFrame, NULL, &_latestTextureFrame);
			if(err != noErr){
				NSLog(@"Error creating OpenGL texture");
				return NO;
			}
		}
	}
	//just get the texture
	else if(self.useTexture){
		if(_latestTextureFrame != NULL){
			CVOpenGLTextureRelease(_latestTextureFrame);
			_latestTextureFrame = NULL;
		}
		
		OSStatus error = QTVisualContextCopyImageForTime(_visualContext, NULL, NULL, &_latestTextureFrame);	
		if (error != noErr) {
			CVOpenGLTextureRelease(_latestTextureFrame);
			return NO;
		}
	}
	
	return YES;
}


//writes out the pixels in RGBA format to outbuf
- (void) pixels:(unsigned char*) outbuf
{
	if(!self.usePixels || _latestPixelFrame == NULL){
		return;
	}
	
	CVPixelBufferLockBaseAddress(_latestPixelFrame, 0);
	unsigned char* pix = CVPixelBufferGetBaseAddress(_latestPixelFrame);
	
	//NOTE:
	//CoreVideo works on ARGB, and openFrameworks is RGBA so we need to swizzle the buffer 
	//before we return it to an openFrameworks app.
	//this is a bit tricky since CV pixel buffer's bytes per row are not always the same as movieWidth*4.  
	//We have to use the BPR given by CV for the input buffer, and the movie size for the output buffer
	int x,y, bpr, width, height;
	bpr = CVPixelBufferGetBytesPerRow(_latestPixelFrame);
	width = movieSize.width;
	height = movieSize.height;
	for(y = 0; y < movieSize.height; y++){
		for(x = 0; x < movieSize.width*4; x+=4){
			//copy out the rgb
			memcpy(outbuf+(y*width*4 + x), pix + (y*bpr+x+1), 3);
			//swizzle in the alpha.
			outbuf[(y*width*4 + x)+3] = pix[y*bpr+x];
		}
	}
	
	CVPixelBufferUnlockBaseAddress(_latestPixelFrame, 0);	
}


static inline void argb_to_rgb(unsigned char* src, unsigned char* dst, int numPix)
{
	int i;
	for(i = 0; i < numPix; i++){
		memcpy(dst, src+1, 3);
		src+=4;
		dst+=3;
	}
}

- (BOOL) textureAllocated
{
	return self.useTexture && _latestTextureFrame != NULL;
}

- (GLuint) textureID
{
	return CVOpenGLTextureGetName(_latestTextureFrame);
}

- (GLenum) textureTarget
{
	return CVOpenGLTextureGetTarget(_latestTextureFrame);
}

- (void) bindTexture
{
	if(!self.textureAllocated) return;

	GLuint texID = 0;
	texID = CVOpenGLTextureGetName(_latestTextureFrame);
	
	GLenum target = GL_TEXTURE_RECTANGLE_ARB;
	target = CVOpenGLTextureGetTarget(_latestTextureFrame);
	
	glEnable(target);
	glBindTexture(target, texID);
	
}

- (void) unbindTexture
{
	if(!self.textureAllocated) return;
	
	GLenum target = GL_TEXTURE_RECTANGLE_ARB;
	target = CVOpenGLTextureGetTarget(_latestTextureFrame);
	glDisable(target);	
}

- (void) setRate:(float) rate
{
	[_movie setRate:rate];
}

- (float) rate
{
	return _movie.rate;
}

- (void) setVolume:(float) volume
{
	[_movie setVolume:volume];
}

- (float) volume
{
	return [_movie volume];
}

- (void) setPosition:(CGFloat) position
{
	_movie.currentTime = QTMakeTime(position*movieDuration.timeValue, movieDuration.timeScale);
}

- (CGFloat) position
{
	return 1.0*_movie.currentTime.timeValue / movieDuration.timeValue;		
}

- (void) setFrame:(NSInteger) frame
{
	QTTime qtt = QTMakeTime(frame*frameStep, movieDuration.timeScale);
	//_movie.currentTime = QTMakeTime(frame*frameStep, movieDuration.timeScale);
	TimeRecord tr;
	QTGetTimeRecord(qtt, &tr);
	SetMovieTime([_movie quickTimeMovie], &tr);
}

- (NSInteger) frame
{
	return _movie.currentTime.timeValue / frameStep;
}

- (NSTimeInterval) duration
{
	return 1.0*movieDuration.timeValue / movieDuration.timeScale;
}

- (void) setLoops:(BOOL)loops
{
	[_movie setAttribute:[NSNumber numberWithBool:loops] 
				  forKey:QTMovieLoopsAttribute];
}

- (BOOL) loops
{
	return [[_movie attributeForKey:QTMovieLoopsAttribute] boolValue];
}

- (BOOL) isFinished
{
	return !self.loops && _movie.currentTime.timeValue == movieDuration.timeValue;
}

@end
