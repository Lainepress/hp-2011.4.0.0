-- #hide
--------------------------------------------------------------------------------
-- |
-- Module      :  Graphics.Rendering.OpenGL.GL.Texturing.PixelInternalFormat
-- Copyright   :  (c) Sven Panne 2002-2009
-- License     :  BSD-style (see the file libraries/OpenGL/LICENSE)
-- 
-- Maintainer  :  sven.panne@aedion.de
-- Stability   :  stable
-- Portability :  portable
--
-- This is a purely internal module for (un-)marshaling PixelInternalFormat.
--
--------------------------------------------------------------------------------

module Graphics.Rendering.OpenGL.GL.Texturing.PixelInternalFormat (
   PixelInternalFormat(..), marshalPixelInternalFormat,
   marshalPixelInternalFormat', unmarshalPixelInternalFormat,
) where

import Graphics.Rendering.OpenGL.GL.BasicTypes ( GLint, GLenum )

--------------------------------------------------------------------------------

data PixelInternalFormat =
     Alpha'
   | DepthComponent'
   | Luminance'
   | LuminanceAlpha'
   | Intensity
   | RGB'
   | RGBA'
   | SRGB
   | SRGBAlpha
   | SLuminance
   | SLuminanceAlpha
   | Alpha4
   | Alpha8
   | Alpha12
   | Alpha16
   | DepthComponent16
   | DepthComponent24
   | DepthComponent32
   | Luminance4
   | Luminance8
   | Luminance12
   | Luminance16
   | Luminance4Alpha4
   | Luminance6Alpha2
   | Luminance8Alpha8
   | Luminance12Alpha4
   | Luminance12Alpha12
   | Luminance16Alpha16
   | Intensity4
   | Intensity8
   | Intensity12
   | Intensity16
   | R3G3B2
   | RGB4
   | RGB5
   | RGB8
   | RGB10
   | RGB12
   | RGB16
   | RGBA2
   | RGBA4
   | RGB5A1
   | RGBA8
   | RGB10A2
   | RGBA12
   | RGBA16
   | SRGB8
   | SRGB8Alpha8
   | SLuminance8
   | SLuminance8Alpha8
   | CompressedAlpha
   | CompressedLuminance
   | CompressedLuminanceAlpha
   | CompressedIntensity
   | CompressedRGB
   | CompressedRGBA
   | CompressedSRGB
   | CompressedSRGBAlpha
   | CompressedSLuminance
   | CompressedSLuminanceAlpha
   | DepthComponent32f
   | Depth32fStencil8
   | RGB9E5
   | R11fG11fB10f
   deriving ( Eq, Ord, Show )

marshalPixelInternalFormat :: PixelInternalFormat -> GLint
marshalPixelInternalFormat x = case x of
   Alpha' -> 0x1906
   DepthComponent' -> 0x1902
   Luminance' -> 0x1909
   LuminanceAlpha' -> 0x190a
   RGB' -> 0x1907
   RGBA' -> 0x1908
   SRGB -> 0x8c40
   SRGBAlpha -> 0x8c42
   SLuminance -> 0x8c46
   SLuminanceAlpha -> 0x8c44
   Alpha4 -> 0x803b
   Alpha8 -> 0x803c
   Alpha12 -> 0x803d
   Alpha16 -> 0x803e
   DepthComponent16 -> 0x81a5
   DepthComponent24 -> 0x81a6
   DepthComponent32 -> 0x81a7
   Luminance4 -> 0x803f
   Luminance8 -> 0x8040
   Luminance12 -> 0x8041
   Luminance16 -> 0x8042
   Luminance4Alpha4 -> 0x8043
   Luminance6Alpha2 -> 0x8044
   Luminance8Alpha8 -> 0x8045
   Luminance12Alpha4 -> 0x8046
   Luminance12Alpha12 -> 0x8047
   Luminance16Alpha16 -> 0x8048
   Intensity -> 0x8049
   Intensity4 -> 0x804a
   Intensity8 -> 0x804b
   Intensity12 -> 0x804c
   Intensity16 -> 0x804d
   R3G3B2 -> 0x2a10
   RGB4 -> 0x804f
   RGB5 -> 0x8050
   RGB8 -> 0x8051
   RGB10 -> 0x8052
   RGB12 -> 0x8053
   RGB16 -> 0x8054
   RGBA2 -> 0x8055
   RGBA4 -> 0x8056
   RGB5A1 -> 0x8057
   RGBA8 -> 0x8058
   RGB10A2 -> 0x8059
   RGBA12 -> 0x805a
   RGBA16 -> 0x805b
   SRGB8 -> 0x8c41
   SRGB8Alpha8 -> 0x8c43
   SLuminance8 -> 0x8c47
   SLuminance8Alpha8 -> 0x8c45
   CompressedAlpha -> 0x84e9
   CompressedLuminance -> 0x84ea
   CompressedLuminanceAlpha -> 0x84eb
   CompressedIntensity -> 0x84ec
   CompressedRGB -> 0x84ed
   CompressedRGBA -> 0x84ee
   CompressedSRGB -> 0x8c48
   CompressedSRGBAlpha -> 0x8c49
   CompressedSLuminance -> 0x8c4a
   CompressedSLuminanceAlpha -> 0x8c4b
   DepthComponent32f -> 0x8CAC
   Depth32fStencil8 -> 0x8CAD
   RGB9E5 -> 0x8C3D
   R11fG11fB10f -> 0x8C3A

-- *sigh* The OpenGL API is sometimes a bit creative in its usage of types...
marshalPixelInternalFormat' :: PixelInternalFormat -> GLenum
marshalPixelInternalFormat' = fromIntegral . marshalPixelInternalFormat

unmarshalPixelInternalFormat :: GLint -> PixelInternalFormat
unmarshalPixelInternalFormat x
   | x == 0x1906 = Alpha'
   | x == 0x1902 = DepthComponent'
   | x == 0x1909 = Luminance'
   | x == 0x190a = LuminanceAlpha'
   | x == 0x1907 = RGB'
   | x == 0x1908 = RGBA'
   | x == 0x8c40 = SRGB
   | x == 0x8c42 = SRGBAlpha
   | x == 0x8c46 = SLuminance
   | x == 0x8c44 = SLuminanceAlpha
   | x == 0x803b = Alpha4
   | x == 0x803c = Alpha8
   | x == 0x803d = Alpha12
   | x == 0x803e = Alpha16
   | x == 0x81a5 = DepthComponent16
   | x == 0x81a6 = DepthComponent24
   | x == 0x81a7 = DepthComponent32
   | x == 0x803f = Luminance4
   | x == 0x8040 = Luminance8
   | x == 0x8041 = Luminance12
   | x == 0x8042 = Luminance16
   | x == 0x8043 = Luminance4Alpha4
   | x == 0x8044 = Luminance6Alpha2
   | x == 0x8045 = Luminance8Alpha8
   | x == 0x8046 = Luminance12Alpha4
   | x == 0x8047 = Luminance12Alpha12
   | x == 0x8048 = Luminance16Alpha16
   | x == 0x8049 = Intensity
   | x == 0x804a = Intensity4
   | x == 0x804b = Intensity8
   | x == 0x804c = Intensity12
   | x == 0x804d = Intensity16
   | x == 0x2a10 = R3G3B2
   | x == 0x804f = RGB4
   | x == 0x8050 = RGB5
   | x == 0x8051 = RGB8
   | x == 0x8052 = RGB10
   | x == 0x8053 = RGB12
   | x == 0x8054 = RGB16
   | x == 0x8055 = RGBA2
   | x == 0x8056 = RGBA4
   | x == 0x8057 = RGB5A1
   | x == 0x8058 = RGBA8
   | x == 0x8059 = RGB10A2
   | x == 0x805a = RGBA12
   | x == 0x805b = RGBA16
   | x == 0x8c41 = SRGB8
   | x == 0x8c43 = SRGB8Alpha8
   | x == 0x8c47 = SLuminance8
   | x == 0x8c45 = SLuminance8Alpha8
   | x == 0x84e9 = CompressedAlpha
   | x == 0x84ea = CompressedLuminance
   | x == 0x84eb = CompressedLuminanceAlpha
   | x == 0x84ec = CompressedIntensity
   | x == 0x84ed = CompressedRGB
   | x == 0x84ee = CompressedRGBA
   | x == 0x8c48 = CompressedSRGB
   | x == 0x8c49 = CompressedSRGBAlpha
   | x == 0x8c4a = CompressedSLuminance
   | x == 0x8c4b = CompressedSLuminanceAlpha
   | x == 0x8CAC = DepthComponent32f
   | x == 0x8CAD = Depth32fStencil8
   | x == 0x8C3D = RGB9E5
   -- legacy values
   | x == 1 = Luminance'
   | x == 2 = LuminanceAlpha'
   | x == 3 = RGB'
   | x == 4 = RGBA'
   | otherwise = error ("unmarshalPixelInternalFormat: illegal value " ++ show x)

-- Note: The following formats are still missing, it's a bit unclear how to
-- handle these nicely. From the EXT_texture_sRGB spec:
--
--    Accepted by the <internalformat> parameter of TexImage2D, CopyTexImage2D,
--    and CompressedTexImage2DARB and the <format> parameter of
--    CompressedTexSubImage2DARB:
--
--       COMPRESSED_SRGB_S3TC_DXT1_EXT                  0x8C4C
--       COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT            0x8C4D
--       COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT            0x8C4E
--       COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT            0x8C4F
