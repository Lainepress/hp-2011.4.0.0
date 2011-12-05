{-# LANGUAGE Rank2Types #-}
-- | Allows testing of monadic values.
module Test.QuickCheck.Monadic where

--------------------------------------------------------------------------
-- imports

import Test.QuickCheck.Gen
import Test.QuickCheck.Property

import Control.Monad
  ( liftM
  )

import Control.Monad.ST

-- instance of monad transformer?

--------------------------------------------------------------------------
-- type PropertyM

newtype PropertyM m a =
  MkPropertyM { unPropertyM :: (a -> Gen (m Property)) -> Gen (m Property) }

instance Functor (PropertyM m) where
  fmap f (MkPropertyM m) = MkPropertyM (\k -> m (k . f))

instance Monad m => Monad (PropertyM m) where
  return x            = MkPropertyM (\k -> k x)
  MkPropertyM m >>= f = MkPropertyM (\k -> m (\a -> unPropertyM (f a) k))
  fail s              = stop (failed { reason = s })

stop :: (Testable prop, Monad m) => prop -> PropertyM m a
stop p = MkPropertyM (\_k -> return (return (property p)))

-- should think about strictness/exceptions here
--assert :: Testable prop => prop -> PropertyM m ()
assert :: Monad m => Bool -> PropertyM m ()
assert True = return ()
assert False = fail "Assertion failed"

-- should think about strictness/exceptions here
pre :: Monad m => Bool -> PropertyM m ()
pre True = return ()
pre False = stop rejected

-- should be called lift?
run :: Monad m => m a -> PropertyM m a
run m = MkPropertyM (liftM (m >>=) . promote)

pick :: (Monad m, Show a) => Gen a -> PropertyM m a
pick gen = MkPropertyM $ \k ->
  do a <- gen
     mp <- k a
     return (do p <- mp
                return (forAll (return a) (const p)))

wp :: Monad m => m a -> (a -> PropertyM m b) -> PropertyM m b
wp m k = run m >>= k

forAllM :: (Monad m, Show a) => Gen a -> (a -> PropertyM m b) -> PropertyM m b
forAllM gen k = pick gen >>= k

monitor :: Monad m => (Property -> Property) -> PropertyM m ()
monitor f = MkPropertyM (\k -> (f `liftM`) `fmap` (k ()))

-- run functions

monadic :: Monad m => (m Property -> Property) -> PropertyM m a -> Property
monadic runner m = property (fmap runner (monadic' m))

monadic' :: Monad m => PropertyM m a -> Gen (m Property)
monadic' (MkPropertyM m) = m (const (return (return (property True))))

monadicIO :: PropertyM IO a -> Property
monadicIO = monadic morallyDubiousIOProperty

monadicST :: (forall s. PropertyM (ST s) a) -> Property
monadicST m = property (runSTGen (monadic' m))

runSTGen :: (forall s. Gen (ST s a)) -> Gen a
runSTGen g = MkGen $ \r n -> runST (unGen g r n)

--------------------------------------------------------------------------
-- the end.
