-- | This module handles the creation of new bullets.
module WhatIsThisGame.Controllers.Bullet (bullets) where

--------------------
-- Global Imports --
import Control.Applicative
import Control.Monad.Fix
import FRP.Elerea.Param
import Control.Lens
import Data.Maybe
import Linear.V2

-------------------
-- Local Imports --
import WhatIsThisGame.Collision
import WhatIsThisGame.Input
import WhatIsThisGame.Data

----------
-- Code --

-- | The size of a bullet.
bulletSize :: V2 Float
bulletSize = V2 3 1.5

-- | The velocity of a bullet.
bulletSpeed :: V2 Float
bulletSpeed = V2 50 0

-- | The default player bullet.
playerBullet :: V2 Float -> V2 Float -> Bullet
playerBullet pos size =
  Bullet { getBulletType     = PlayerBullet
         , getBulletPosition = pos'
         , getBulletSize     = bulletSize
         , getBulletDamage   = 15
         , getBulletSpeed    = bulletSpeed
         }
  where pos' = pos + size - (bulletSize / 2) - (V2 (size ^. _x / 8) (size ^. _y) / 2)

-- | The default enemy bullet.
enemyBullet :: V2 Float -> V2 Float -> Bullet
enemyBullet pos size =
  Bullet { getBulletType     = EnemyBullet
         , getBulletPosition = pos'
         , getBulletSize     = bulletSize
         , getBulletDamage   = 15
         , getBulletSpeed    = -bulletSpeed
         }
  where pos' = pos + (V2 0 (size ^. _y / 2)) - (bulletSize - 2)

-- | Making a bullet from @'BulletType'@.
makeBullet :: BulletType -> V2 Float -> V2 Float -> Bullet
makeBullet PlayerBullet pos size = playerBullet pos size
makeBullet EnemyBullet  pos size = enemyBullet  pos size

-- | Stepping a single bullet.
stepBullet :: Float -> [Entity] -> Float -> Bullet -> Maybe Bullet
stepBullet dt enemies w b =
  let np = getBulletPosition b + getBulletSpeed b * pure dt in
    if np ^. _x > w
      then Nothing
      else findDeath enemies $ b { getBulletPosition = np }
  where findDeath :: [Entity] -> Bullet -> Maybe Bullet
        findDeath    []  b' = Just b'
        findDeath (e:es) b' =
          if looseCollides e b'
            then Nothing
            else findDeath es b'

-- | Stepping a whole list of @'Maybe' 'Bullet'@.
stepMaybeBullets :: Float -> [Entity] -> Float -> [Maybe Bullet] -> [Maybe Bullet]
stepMaybeBullets  _  _ _     [] = []
stepMaybeBullets dt es w (b:bs) =
  (b >>= stepBullet dt es w) : stepMaybeBullets dt es w bs

-- | Possibly appending a bulle to a @['Maybe' 'Bullet']@.
maybeAppendBullet :: Bool -> BulletType -> V2 Float -> V2 Float -> [Maybe Bullet] -> [Maybe Bullet]
maybeAppendBullet False          _   _   _ bs = bs
maybeAppendBullet  True bulletType pos size bs =
  Just (makeBullet bulletType pos size) : bs

-- | The same as bullets, but without the @'Maybe'@s filtered out.
maybeBullets :: Signal World
             -> Signal Bool
             -> Signal BulletType
             -> Signal (V2 Float)
             -> Signal (V2 Float)
             -> Signal [Maybe Bullet]
             -> SignalGen Float (Signal [Maybe Bullet])
maybeBullets sWorld sMake sBulletType sPos sSize sBullets = do
  sDt    <- input
  sWidth <- fmap (fmap (^. _x)) renderSize

  delay [] $ stepMaybeBullets <$> sDt <*> fmap worldGetEnemies sWorld <*> sWidth <*>
    (maybeAppendBullet <$> sMake <*> sBulletType <*> sPos <*> sSize <*> sBullets)

-- | Produces bullets given a number of signals describing its creation.
bullets :: Signal World -> Signal Bool -> Signal BulletType -> Signal (V2 Float) -> Signal (V2 Float) -> SignalGen Float (Signal [Bullet])
bullets sWorld sMake sBulletType sPos sSize =
  fmap (fmap catMaybes) $ mfix $ maybeBullets sWorld sMake sBulletType sPos sSize
