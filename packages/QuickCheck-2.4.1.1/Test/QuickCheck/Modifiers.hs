{-# LANGUAGE CPP #-}
#ifndef NO_MULTI_PARAM_TYPE_CLASSES
{-# LANGUAGE MultiParamTypeClasses #-}
#endif
#ifndef NO_NEWTYPE_DERIVING
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
#endif
-- | Modifiers for test data.
--
-- These types do things such as restricting the kind of test data that can be generated.
-- They can be pattern-matched on in properties as a stylistic
-- alternative to using explicit quantification.
-- 
-- Examples:
-- 
-- @
-- -- Functions cannot be shown (but see "Test.QuickCheck.Function")
-- prop_TakeDropWhile ('Blind' p) (xs :: ['A']) =
--   takeWhile p xs ++ dropWhile p xs == xs
-- @
--
-- @
-- prop_TakeDrop ('NonNegative' n) (xs :: ['A']) =
--   take n xs ++ drop n xs == xs
-- @
--
-- @
-- -- cycle does not work for empty lists
-- prop_Cycle ('NonNegative' n) ('NonEmpty' (xs :: ['A'])) =
--   take n (cycle xs) == take n (xs ++ cycle xs)
-- @
--
-- @
-- -- Instead of 'forAll' 'orderedList'
-- prop_Sort ('Ordered' (xs :: ['OrdA'])) =
--   sort xs == xs
-- @
module Test.QuickCheck.Modifiers
  (
  -- ** Type-level modifiers for changing generator behavior
    Blind(..)
  , Fixed(..)
  , OrderedList(..)
  , NonEmptyList(..)
  , Positive(..)
  , NonZero(..)
  , NonNegative(..)
  , Smart(..)
  , Shrink2(..)
  , Shrinking(..)
  , ShrinkState(..)
  )
 where

--------------------------------------------------------------------------
-- imports

import Test.QuickCheck.Gen
import Test.QuickCheck.Arbitrary

import Data.List
  ( sort
  )

--------------------------------------------------------------------------
-- | @Blind x@: as x, but x does not have to be in the 'Show' class.
newtype Blind a = Blind a
 deriving ( Eq, Ord
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )

instance Show (Blind a) where
  show _ = "(*)"

instance Arbitrary a => Arbitrary (Blind a) where
  arbitrary = Blind `fmap` arbitrary

  shrink (Blind x) = [ Blind x' | x' <- shrink x ]

--------------------------------------------------------------------------
-- | @Fixed x@: as x, but will not be shrunk.
newtype Fixed a = Fixed a
 deriving ( Eq, Ord, Show, Read
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )

instance Arbitrary a => Arbitrary (Fixed a) where
  arbitrary = Fixed `fmap` arbitrary
  
  -- no shrink function

--------------------------------------------------------------------------
-- | @Ordered xs@: guarantees that xs is ordered.
newtype OrderedList a = Ordered [a]
 deriving ( Eq, Ord, Show, Read )

instance (Ord a, Arbitrary a) => Arbitrary (OrderedList a) where
  arbitrary = Ordered `fmap` orderedList

  shrink (Ordered xs) =
    [ Ordered xs'
    | xs' <- shrink xs
    , sort xs' == xs'
    ]

--------------------------------------------------------------------------
-- | @NonEmpty xs@: guarantees that xs is non-empty.
newtype NonEmptyList a = NonEmpty [a]
 deriving ( Eq, Ord, Show, Read )

instance Arbitrary a => Arbitrary (NonEmptyList a) where
  arbitrary = NonEmpty `fmap` (arbitrary `suchThat` (not . null))

  shrink (NonEmpty xs) =
    [ NonEmpty xs'
    | xs' <- shrink xs
    , not (null xs')
    ]

--------------------------------------------------------------------------
-- | @Positive x@: guarantees that @x \> 0@.
newtype Positive a = Positive a
 deriving ( Eq, Ord, Show, Read
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )
instance (Num a, Ord a, Arbitrary a) => Arbitrary (Positive a) where
  arbitrary =
    (Positive . abs) `fmap` (arbitrary `suchThat` (/= 0))

  shrink (Positive x) =
    [ Positive x'
    | x' <- shrink x
    , x' > 0
    ]

--------------------------------------------------------------------------
-- | @NonZero x@: guarantees that @x \/= 0@.
newtype NonZero a = NonZero a
 deriving ( Eq, Ord, Show, Read
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )

instance (Num a, Ord a, Arbitrary a) => Arbitrary (NonZero a) where
  arbitrary = fmap NonZero $ arbitrary `suchThat` (/= 0)

  shrink (NonZero x) = [ NonZero x' | x' <- shrink x, x' /= 0 ]

--------------------------------------------------------------------------
-- | @NonNegative x@: guarantees that @x \>= 0@.
newtype NonNegative a = NonNegative a
 deriving ( Eq, Ord, Show, Read
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )

instance (Num a, Ord a, Arbitrary a) => Arbitrary (NonNegative a) where
  arbitrary =
    frequency
      -- why is this distrbution like this?
      [ (5, (NonNegative . abs) `fmap` arbitrary)
      , (1, return (NonNegative 0))
      ]

  shrink (NonNegative x) =
    [ NonNegative x'
    | x' <- shrink x
    , x' >= 0
    ]

--------------------------------------------------------------------------
-- | @Shrink2 x@: allows 2 shrinking steps at the same time when shrinking x
newtype Shrink2 a = Shrink2 a
 deriving ( Eq, Ord, Show, Read
#ifndef NO_NEWTYPE_DERIVING
          , Num, Integral, Real, Enum
#endif
          )

instance Arbitrary a => Arbitrary (Shrink2 a) where
  arbitrary =
    Shrink2 `fmap` arbitrary

  shrink (Shrink2 x) =
    [ Shrink2 y | y <- shrink_x ] ++
    [ Shrink2 z
    | y <- shrink_x
    , z <- shrink y
    ]
   where
    shrink_x = shrink x

--------------------------------------------------------------------------
-- | @Smart _ x@: tries a different order when shrinking.
data Smart a =
  Smart Int a

instance Show a => Show (Smart a) where
  showsPrec n (Smart _ x) = showsPrec n x

instance Arbitrary a => Arbitrary (Smart a) where
  arbitrary =
    do x <- arbitrary
       return (Smart 0 x)

  shrink (Smart i x) = take i' ys `ilv` drop i' ys
   where
    ys = [ Smart j y | (j,y) <- [0..] `zip` shrink x ]
    i' = 0 `max` (i-2)

    []     `ilv` bs     = bs
    as     `ilv` []     = as
    (a:as) `ilv` (b:bs) = a : b : (as `ilv` bs)
    
{-
  shrink (Smart i x) = part0 ++ part2 ++ part1
   where
    ys = [ Smart i y | (i,y) <- [0..] `zip` shrink x ]
    i' = 0 `max` (i-2)
    k  = i `div` 10
    
    part0 = take k ys
    part1 = take (i'-k) (drop k ys)
    part2 = drop i' ys
-}

    -- drop a (drop b xs) == drop (a+b) xs           | a,b >= 0
    -- take a (take b xs) == take (a `min` b) xs
    -- take a xs ++ drop a xs == xs
    
    --    take k ys ++ take (i'-k) (drop k ys) ++ drop i' ys
    -- == take k ys ++ take (i'-k) (drop k ys) ++ drop (i'-k) (drop k ys)
    -- == take k ys ++ take (i'-k) (drop k ys) ++ drop (i'-k) (drop k ys)
    -- == take k ys ++ drop k ys
    -- == ys

#ifndef NO_MULTI_PARAM_TYPE_CLASSES
--------------------------------------------------------------------------
-- | @Shrinking _ x@: allows for maintaining a state during shrinking.
data Shrinking s a =
  Shrinking s a

class ShrinkState s a where
  shrinkInit  :: a -> s
  shrinkState :: a -> s -> [(a,s)]

instance Show a => Show (Shrinking s a) where
  showsPrec n (Shrinking _ x) = showsPrec n x

instance (Arbitrary a, ShrinkState s a) => Arbitrary (Shrinking s a) where
  arbitrary =
    do x <- arbitrary
       return (Shrinking (shrinkInit x) x)

  shrink (Shrinking s x) =
    [ Shrinking s' x'
    | (x',s') <- shrinkState x s
    ]

#endif /* NO_MULTI_PARAM_TYPE_CLASSES */

--------------------------------------------------------------------------
-- the end.
