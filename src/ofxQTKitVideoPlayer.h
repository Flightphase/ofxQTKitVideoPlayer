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

#ifndef OFX_QTKIT_VIDEO_PLAYER
#define OFX_QTKIT_VIDEO_PLAYER

#include "ofMain.h"

#ifdef __OBJC__
#import "QTKitMovieRenderer.h"
#endif

//different modes for the video player to run in
//this mode just uses the quicktime texture and is really fast, but offers no pixels-level access
#define OFXQTVIDEOPLAYER_MODE_TEXTURE_ONLY 0 
//this mode just renders pixels and can't be drawn directly to the screen
#define OFXQTVIDEOPLAYER_MODE_PIXELS_ONLY 1
//this mode renders pixels and textures, is a little bit slower than DRAW_ONLY, but faster than uploading your own texture
#define OFXQTVIDEOPLAYER_MODE_PIXELS_AND_TEXTURE 2

class ofxQTKitVideoPlayer  : public ofBaseVideoPlayer
{
  public:	

	ofxQTKitVideoPlayer();
	virtual ~ofxQTKitVideoPlayer();
	
	bool				loadMovie(string path); //default mode is OFXQTVIDEOPLAYER_MODE_TEXTURE_ONLY
	bool				loadMovie(string path, int mode);
	
	void 				closeMovie();
	void 				close();
	

	void				idleMovie();
	void				update();
	void				play();
	void				stop();
	void				pause();

	/// depracated but left for backwards compatability -- use getTexture()->bind() now moving forward
	void				bind();
	void				unbind();
	
	bool 				isFrameNew(); //returns true if the frame has changed in this update cycle
	
	//gets regular openFrameworks compatible RGBA pixels
	unsigned char * 	getPixels();
	ofPixelsRef			getPixelsRef();
	
	//returns an ofTexture will be NULL if OFXQTVIDEOPLAYER_MODE_PIXELS_ONLY
	ofTexture *			getTexture();
	
	float 				getPosition();
	float				getPositionInSeconds();
	float 				getSpeed();
	bool				getMovieLoopState();
	float 				getDuration();
	bool				getIsMovieDone();
	int					getTotalNumFrames();
	int					getCurrentFrame();


	void 				setPosition(float pct);
	void 				setVolume(int volume);
	void 				setLoopState(bool loops);
	void 				setLoopState(int ofLoopState);
	void   				setSpeed(float speed);
	void				setFrame(int frame);  // frame 0 = first frame...
	
	void 				draw(ofRectangle drawRect);
	void 				draw(float x, float y, float w, float h);
	void 				draw(float x, float y);
	
	float				getWidth();
	float				getHeight();
		
	bool				isPaused();
	bool				isLoaded();
	bool				isPlaying();

	//TODO
	virtual void		firstFrame(){}
	virtual void		nextFrame(){}
	virtual void		previousFrame(){}
	

	
  protected:
	bool			bNewFrame;
	bool 			bHavePixelsChanged;	
	float			duration;
	
	//pulls texture data from the movie renderer into our ofTexture
	void updateTexture();
	
	//do lazy allocation and copy on these so it's faster if they aren't used
	ofTexture tex;
	ofPixels pixels;
	
	//This #ifdef is so you can include this .h file in .cpp files
	//and avoid ugly casts in the .m file
	#ifdef __OBJC__
	QTKitMovieRenderer* moviePlayer;
	#else
	void* moviePlayer;
	#endif
	
};

#endif