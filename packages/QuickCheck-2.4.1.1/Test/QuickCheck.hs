{-# LANGUAGE CPP #-}
module Test.QuickCheck
  ( 
    -- * Running tests
    quickCheck
  , Args(..), Result(..)
  , stdArgs
  , quickCheckWith
  , quickCheckWithResult
  , quickCheckResult
    -- ** Running tests verbosely
  , verboseCheck
  , verboseCheckWith
  , verboseCheckWithResult
  , verboseCheckResult
  , verbose
    
    -- * Random generation
  , Gen
    -- ** Generator combinators
  , sized
  , resize
  , choose
  , promote
  , suchThat
  , suchThatMaybe
  , oneof
  , frequency
  , elements
  , growingElements
  , listOf
  , listOf1
  , vectorOf
    -- ** Generators which use Arbitrary
  , vector
  , orderedList
    -- ** Generator debugging
  , sample
  , sample'

    -- * Arbitrary and CoArbitrary classes
  , Arbitrary(..)
  , CoArbitrary(..)
  
    -- ** Helper functions for implementing arbitrary
  , arbitrarySizedIntegral
  , arbitrarySizedFractional
  , arbitrarySizedBoundedIntegral
  , arbitraryBoundedIntegral
  , arbitraryBoundedRandom
    -- ** Helper functions for implementing shrink
  , shrinkNothing
  , shrinkIntegral
  , shrinkRealFrac
    -- ** Helper functions for implementing coarbitrary
  , variant
  , (><)
  , coarbitraryIntegral
  , coarbitraryReal
  , coarbitraryShow

    -- ** Type-level modifiers for changing generator behavior
  , Blind(..)
  , Fixed(..)
  , OrderedList(..)
  , NonEmptyList(..)
  , Positive(..)
  , NonZero(..)
  , NonNegative(..)
  , Smart(..)
  , Shrink2(..)
#ifndef NO_MULTI_PARAM_TYPE_CLASSES
  , Shrinking(..)
#endif
  , ShrinkState(..)

    -- * Properties
  , Property, Prop, Testable(..)
    -- ** Property combinators
  , mapSize
  , shrinking
  , (==>)
  , forAll
  , forAllShrink
    -- *** Experimental combinators for conjunction and disjunction
  , (.&.)
  , (.&&.)
  , conjoin
  , (.||.)
  , disjoin
    -- *** Handling failure
  , whenFail
  , printTestCase
  , whenFail'
  , expectFailure
  , within
    -- *** Test distribution
  , label
  , collect
  , classify
  , cover
  
    -- * Text formatting
  , Str(..)
  , ranges
  )
 where

--------------------------------------------------------------------------
-- imports

import Test.QuickCheck.Gen
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Modifiers
import Test.QuickCheck.Property hiding ( Result(..) )
import Test.QuickCheck.Test
import Test.QuickCheck.Text

--------------------------------------------------------------------------
-- the end.
