{-# LANGUAGE TypeOperators, GADTs #-}
module Test.QuickCheck.Function
  ( Fun(..)
  , apply
  , (:->)
  , Function(..)
  , functionMap
  , functionShow
  )
 where

--------------------------------------------------------------------------
-- imports

import Test.QuickCheck.Gen
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Property
import Test.QuickCheck.Poly
import Test.QuickCheck.Modifiers

import Data.Char
import Data.Word
import Data.List( intersperse )
import Data.Maybe( fromJust )

--------------------------------------------------------------------------
-- concrete functions

-- the type of possibly partial concrete functions
data a :-> c where
  Pair  :: (a :-> (b :-> c)) -> ((a,b) :-> c)
  (:+:) :: (a :-> c) -> (b :-> c) -> (Either a b :-> c)
  Unit  :: c -> (() :-> c)
  Nil   :: a :-> c
  Table :: Eq a => [(a,c)] -> (a :-> c)
  Map   :: (a -> b) -> (b -> a) -> (b :-> c) -> (a :-> c)

instance Functor ((:->) a) where
  fmap f (Pair p)    = Pair (fmap (fmap f) p)
  fmap f (p:+:q)     = fmap f p :+: fmap f q
  fmap f (Unit c)    = Unit (f c)
  fmap f Nil         = Nil
  fmap f (Table xys) = Table [ (x,f y) | (x,y) <- xys ]
  fmap f (Map g h p) = Map g h (fmap f p)

instance (Show a, Show b) => Show (a:->b) where
  show p = showFunction p Nothing

-- only use this on finite functions
showFunction :: (Show a, Show b) => (a :-> b) -> Maybe b -> String
showFunction p md =
  "{" ++ concat (intersperse "," ( [ show x ++ "->" ++ show c
                                   | (x,c) <- table p
                                   ]
                                ++ [ "_->" ++ show d
                                   | Just d <- [md]
                                   ] )) ++ "}"

-- turning a concrete function into an abstract function (with a default result)
abstract :: (a :-> c) -> c -> (a -> c)
abstract (Pair p)    d (x,y) = abstract (fmap (\q -> abstract q d y) p) d x
abstract (p :+: q)   d exy   = either (abstract p d) (abstract q d) exy
abstract (Unit c)    _ _     = c
abstract Nil         d _     = d
abstract (Table xys) d x     = head ([y | (x',y) <- xys, x == x'] ++ [d])
abstract (Map g _ p) d x     = abstract p d (g x)

-- generating a table from a concrete function
table :: (a :-> c) -> [(a,c)]
table (Pair p)    = [ ((x,y),c) | (x,q) <- table p, (y,c) <- table q ]
table (p :+: q)   = [ (Left x, c) | (x,c) <- table p ]
                 ++ [ (Right y,c) | (y,c) <- table q ]
table (Unit c)    = [ ((), c) ]
table Nil         = []
table (Table xys) = xys
table (Map _ h p) = [ (h x, c) | (x,c) <- table p ]

-- finding a default result

-- breadth-first search (can't use depth-first search!)
data Steps a = Step (Steps a) | Fail | Result a

(#) :: Steps a -> Steps a -> Steps a
Result x # t        = Result x
s        # Result y = Result y
Fail     # t        = t
s        # Fail     = s
Step s   # Step t   = Step (s # t)

instance Monad Steps where
  Step s   >>= k = Step (s >>= k)
  Result x >>= k = k x
  Fail     >>= k = Fail

  return x = Result x

run :: Steps a -> Maybe a
run (Step s)   = run s
run (Result x) = Just x
run Fail       = Nothing

defaultSteps :: (a :-> c) -> Steps c
defaultSteps (Pair p)          = defaultSteps p >>= defaultSteps
defaultSteps (p :+: q)         = Step (defaultSteps p # defaultSteps q)
defaultSteps (Unit c)          = Result c
defaultSteps (Table ((_,y):_)) = Result y
defaultSteps (Map _ _ p)       = defaultSteps p
defaultSteps _                 = Fail

defaultResult :: (a :-> c) -> Maybe c
defaultResult = run . defaultSteps

--------------------------------------------------------------------------
-- Function

class Function a where
  function :: (a->b) -> (a:->b)

-- basic instances
  
instance Function () where
  function f = Unit (f ())

instance Function Word8 where
  function f = Table [(x,f x) | x <- [0..255]]

instance (Function a, Function b) => Function (a,b) where
  function f = Pair (function `fmap` function (curry f))

instance (Function a, Function b) => Function (Either a b) where
  function f = function (f . Left) :+: function (f . Right)

-- other instances

functionMap :: Function b => (a->b) -> (b->a) -> (a->c) -> (a:->c)
functionMap g h f = Map g h (function (\b -> f (h b)))

functionShow :: (Show a, Read a) => (a->c) -> (a:->c)
functionShow f = functionMap show read f

instance Function a => Function [a] where
  function = functionMap g h
   where
    g []     = Left ()
    g (x:xs) = Right (x,xs)

    h (Left _)       = []
    h (Right (x,xs)) = x:xs

instance Function a => Function (Maybe a) where
  function = functionMap g h
   where
    g Nothing  = Left ()
    g (Just x) = Right x

    h (Left _)  = Nothing
    h (Right x) = Just x

instance Function Bool where
  function = functionMap g h
   where
    g False = Left ()
    g True  = Right ()
    
    h (Left _)  = False
    h (Right _) = True

instance Function Integer where
  function = functionMap gInteger hInteger
   where
    gInteger n | n < 0     = Left (gNatural (abs n - 1))
               | otherwise = Right (gNatural n)
    
    hInteger (Left ws)  = -(hNatural ws + 1)
    hInteger (Right ws) = hNatural ws
    
    gNatural 0 = []
    gNatural n = (fromIntegral (n `mod` 256) :: Word8) : gNatural (n `div` 256)
    
    hNatural []     = 0
    hNatural (w:ws) = fromIntegral w + 256 * hNatural ws

instance Function Int where
  function = functionMap fromIntegral fromInteger

instance Function Char where
  function = functionMap ord' chr'
   where
    ord' c = fromIntegral (ord c) :: Word8
    chr' n = chr (fromIntegral n)

-- poly instances

instance Function A where
  function = functionMap unA A

instance Function B where
  function = functionMap unB B

instance Function C where
  function = functionMap unC C

instance Function OrdA where
  function = functionMap unOrdA OrdA

instance Function OrdB where
  function = functionMap unOrdB OrdB

instance Function OrdC where
  function = functionMap unOrdC OrdC

-- instance Arbitrary

instance (Function a, CoArbitrary a, Arbitrary b) => Arbitrary (a:->b) where
  arbitrary = function `fmap` arbitrary
  shrink    = shrinkFun shrink

--------------------------------------------------------------------------
-- shrinking

shrinkFun :: (c -> [c]) -> (a :-> c) -> [a :-> c]
shrinkFun shr (Pair p) =
  [ pair p' | p' <- shrinkFun (\q -> shrinkFun shr q) p ]
 where
  pair Nil = Nil
  pair p   = Pair p

shrinkFun shr (p :+: q) =
  [ p .+. Nil | not (isNil q) ] ++
  [ Nil .+. q | not (isNil p) ] ++
  [ p  .+. q' | q' <- shrinkFun shr q ] ++
  [ p' .+. q  | p' <- shrinkFun shr p ]
 where
  isNil :: (a :-> b) -> Bool
  isNil Nil = True
  isNil _   = False
 
  Nil .+. Nil = Nil
  p   .+. q   = p :+: q

shrinkFun shr (Unit c) =
  [ Nil ] ++
  [ Unit c' | c' <- shr c ]

shrinkFun shr (Table xys) =
  [ table xys' | xys' <- shrinkList shrXy xys ]
 where
  shrXy (x,y) = [(x,y') | y' <- shr y]
  
  table []  = Nil
  table xys = Table xys

shrinkFun shr Nil =
  []

shrinkFun shr (Map g h p) =
  [ mapp g h p' | p' <- shrinkFun shr p ]
 where
  mapp g h Nil = Nil
  mapp g h p   = Map g h p

--------------------------------------------------------------------------
-- the Fun modifier

data Fun a b = Fun (a :-> b, b) (a -> b)

mkFun :: (a :-> b) -> b -> Fun a b
mkFun p d = Fun (p,d) (abstract p d)

apply :: Fun a b -> (a -> b)
apply (Fun _ f) = f

instance (Show a, Show b) => Show (Fun a b) where
  show (Fun (p,d) _) = showFunction p (Just d)

instance (Function a, CoArbitrary a, Arbitrary b) => Arbitrary (Fun a b) where
  arbitrary =
    do p <- arbitrary
       return (mkFun p (fromJust (defaultResult p)))

  shrink (Fun (p,d) _) =
       [ mkFun p' d' | p' <- shrink p, Just d' <- [defaultResult p'] ]
    ++ [ mkFun p' d  | p' <- shrink p ]
    ++ [ mkFun p d'  | d' <- shrink d ]

--------------------------------------------------------------------------
-- the end.
