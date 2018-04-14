-- The main loop of the game, binding everything
-- together from options to characters
------------------------------------------------

{-# LANGUAGE FlexibleContexts #-}

module Game
( game
, beginGame
) where

import System.Exit (exitSuccess)

import SDL.Vect
import SDL (($=))
import qualified SDL
import qualified SDL.Image

import Reflex
import Reflex.SDL2

import Common
import GameSetup
import SDLAnimations
import InputModule

import Guy

-- The main game loop
game :: (ReflexSDL2 r t m, MonadDynamicWriter t [Layer m] m) => GameSetup -> m () 
game setup = do

  -- Create an event for every tick
  tmp <- getDeltaTickEvent
  delta <- holdDyn 0 (fmap ((/ 1000) .fromIntegral) tmp)

  -- Every tick sample the mouses current location
  mouseB <- hold (P $ V2 0 0) =<< performEvent (SDL.getAbsoluteMouseLocation <$ updated delta)

  -- Create the player
  animsList <- loadAnimations "Assets/rogue.json"
  pTex <- getTextureFromImg (renderer setup) "Assets/rogue.png"
  let animationSet = getAnimationSet "rogue" "male" =<< animsList
      animation = getAnimation "walk" =<< animationSet
      pAnimState = 
        AnimationState animationSet animation [] "idle" 0 0
  player <- handleGuy (updated delta) $ createGuy 0 0 pTex pAnimState
  player' <- handleGuy (updated delta) $ createGuy 9 9 pTex pAnimState

  -- Every tick, render the background and all entities

  -- Render background. Works and compiles
  commitLayer $ ffor delta $ \_ -> SDL.copy (renderer setup) (texmex setup) Nothing Nothing

  -- Prints "Test print" every frame. Works and compiles
  commitLayer $ ffor delta $ const testPrint
  
  -- Should render the background. Does NOT work but compiles
  performEvent_ $ ffor (updated delta) $ \_ -> SDL.copy (renderer setup) (texmex setup) Nothing Nothing

  -- Should render characters to the screen. Does NOT work but compiles
  performEvent_ $ fmap (renderGuys (renderer setup)) (foo [current player, current player'] (updated delta))

  -- Should print "Test print" every frame. Works and compiles.
  performEvent_ $ fmap (const testPrint) (updated delta)

  -- Trying to render the characters the same way as I render the background, but does NOT compile
  -- This is due to foo producing Events rather than dynamics
  --commitLayer $ fmap (renderGuys (renderer setup)) (foo [current player, current player'] (updated delta))

  -- Quit on a quit event
  evQuit <- getQuitEvent
  performEvent_ $ ffor evQuit $ \() -> liftIO $ do
    SDL.quit
    SDL.destroyWindow $ window setup
    exitSuccess

-- Start the game loop properly
beginGame :: GameSetup -> IO ()
beginGame gs =
  host () $ do
    (_, dynLayers) <- runDynamicWriterT $ game gs
    performEvent_ $ ffor (updated dynLayers) $ \layers -> do
      rendererDrawColor r $= V4 0 0 0 255
      clear r
      sequence_ layers
      present r
  where w = window gs
        r = renderer gs

foo :: Reflex t => [Behavior t a] -> Event t b -> Event t [a]
foo gs ev = foldr (attachWith (:)) ([] <$ ev) gs

testPrint :: MonadIO m => m ()
testPrint = liftIO $ print "Test print"
