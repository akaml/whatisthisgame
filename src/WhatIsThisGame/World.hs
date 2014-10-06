-- | This module provides the logic for constructing and rendering the game
--   world.
{-# LANGUAGE Arrows #-}
module WhatIsThisGame.World where

--------------------
-- Global Imports --
import Control.Wire
import Data.Monoid

-------------------
-- Local Imports --
import WhatIsThisGame.Controllers.Background
import WhatIsThisGame.Controllers.Player
import WhatIsThisGame.Data

----------
-- Code --

-- | Providing the rendering for a @'World'@.
instance Renderable World where
  render assets (World es) =
    mconcat $ map (render assets) es

-- | The initial state of the world.
initialWorld :: World
initialWorld = World []

-- | Updating the world.
world' :: (HasTime t s, Monoid e) => Wire s e IO World World
world' =
  proc w -> do
    b <- background -< w
    p <- player     -< w

    returnA -< makeWorld b p
  where makeWorld :: Entity -> Entity -> World
        makeWorld b p =
          World $ [b, p]

-- | The front-end for the world.
world :: HasTime t s => Wire s () IO a World
world =
  proc _ -> do
    rec w <- world' -< w
    returnA -< w
