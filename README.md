# windows-terminal-shaders

RETRO.hlsl.  Based on RETROII code found here:
https://github.com/mrange/terminal/blob/pr/mrange/shaderific/samples/PixelShaders/RetroII.hlsl

To use:

Copy the hlsl file to a location on your local machine.  Open windows Terminal and press the shift key when selecting "Settings".  This will open the settings file in your editor of choice.  

Add a line to the configuration section for the console you want to change, updating the {path to hlslfile} to be the location of the file, remembering to use double backslashes

                "experimental.pixelShaderPath": "{path to hlslfile}\\retro.hlsl",

Save the configuration json and open a new console.


There are a number of customisable values at the top of the hlsl file.  Toggling the values at the top of the file will turn the various features on and off.

  // Set these to 1 to enable and 0 to disable each feature
  #define ENABLE_REFRESHLINE 1  // Displays a refresh line scrolling down the screen
  #define ENABLE_VIGNETTING 1  // Darkens the corners of the screen
  #define ENABLE_BAD_CRT 1  // Changes the colour over the curvature of the CRT screen
  #define ENABLE_SCREENLINES 1  // Displays the horizontal lines
  #define ENABLE_HUEOFFSET 0  //  Cycles the hue of the screen
  #define ENABLE_TINT 0  //  Tints the whole screen 
  #define ENABLE_GRAIN 1  // Adds noise to the screen

There are also some values you can tweak to make the effects suit your needs:

  #define GRAIN_INTENSITY 0.03 // Larger values make the grain more visible

  // You can tweak the look by making small adjustments to these values
  #define HUE_OFFSET 0.0f
  #define CHANGE_RATE 0.01f  //Larger values increase the speed of the hue changes
  #define TOLERANCE 0.266f

  #define REFRESHLINE_SIZE 0.04f  //The thickness of the refresh line
  #define REFRESHLINE_STRENGTH 0.5f  //How visible the refresh line is

  #define TINT_COLOR float4(0, 0.7f, 0, 0) // The colour to use to tint the screen

  #define BAD_CRT_EFFECT 0.06f  // Larger numbers make the effect more extreme
