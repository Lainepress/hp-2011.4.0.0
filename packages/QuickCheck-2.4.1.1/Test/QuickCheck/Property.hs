{-# LANGUAGE CPP #-}
module Test.QuickCheck.Property where

--------------------------------------------------------------------------
-- imports

import Test.QuickCheck.Gen
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Text( showErr, putLine )
import Test.QuickCheck.Exception
import Test.QuickCheck.State

#ifndef NO_TIMEOUT
import System.Timeout(timeout)
#endif
import Data.Maybe

--------------------------------------------------------------------------
-- fixities

infixr 0 ==>
infixr 1 .&.
infixr 1 .&&.
infixr 1 .||.

-- The story for exception handling:
--
-- To avoid insanity, we have rules about which terms can throw
-- exceptions when we evaluate them:
--   * A rose tree must evaluate to WHNF without throwing an exception
--   * The 'ok' component of a Result must evaluate to Just True or
--     Just False or Nothing rather than raise an exception
--   * IORose _ must never throw an exception when executed
--
-- Both rose trees and Results may loop when we evaluate them, though,
-- so we have to be careful not to force them unnecessarily.
--
-- We also have to be careful when we use fmap or >>= in the Rose
-- monad that the function we supply is total, or else use
-- protectResults afterwards to install exception handlers. The
-- mapResult function on Properties installs an exception handler for
-- us, though.
--
-- Of course, the user is free to write "error "ha ha" :: Result" if
-- they feel like it. We have to make sure that any user-supplied Rose
-- Results or Results get wrapped in exception handlers, which we do by:
--   * Making the 'property' function install an exception handler
--     round its argument. This function always gets called in the
--     right places, because all our Property-accepting functions are
--     actually polymorphic over the Testable class so they have to
--     call 'property'.
--   * Installing an exception handler round a Result before we put it
--     in a rose tree (the only place Results can end up).

--------------------------------------------------------------------------
-- * Property and Testable types

type Property = Gen Prop

-- | The class of things which can be tested, i.e. turned into a property.
class Testable prop where
  property :: prop -> Property

instance Testable () where
  property _ = property rejected

instance Testable Bool where
  property = property . liftBool

instance Testable Result where
  property = return . MkProp . protectResults . return

instance Testable Prop where
  property (MkProp r) = return . MkProp . ioRose . return $ r

instance Testable prop => Testable (Gen prop) where
  property mp = do p <- mp; property p

-- | Do I/O inside a property. This can obviously lead to unrepeatable
-- testcases, so use with care.
morallyDubiousIOProperty :: Testable prop => IO prop -> Property
morallyDubiousIOProperty = fmap (MkProp . ioRose . fmap unProp) . promote . fmap property

instance (Arbitrary a, Show a, Testable prop) => Testable (a -> prop) where
  property f = forAllShrink arbitrary shrink f

-- ** Exception handling
protect :: (AnException -> a) -> IO a -> IO a
protect f x = either f id `fmap` tryEvaluateIO x

--------------------------------------------------------------------------
-- ** Type Prop

newtype Prop = MkProp{ unProp :: Rose Result }

-- ** type Rose

data Rose a = MkRose a [Rose a] | IORose (IO (Rose a))
-- Only use IORose if you know that the argument is not going to throw an exception!
-- Otherwise, try ioRose.
ioRose :: IO (Rose Result) -> Rose Result
ioRose = IORose . protectRose

joinRose :: Rose (Rose a) -> Rose a
joinRose (IORose rs) = IORose (fmap joinRose rs)
joinRose (MkRose (IORose rm) rs) = IORose $ do r <- rm; return (joinRose (MkRose r rs))
joinRose (MkRose (MkRose x ts) tts) =
  -- first shrinks outer quantification; makes most sense
  MkRose x (map joinRose tts ++ ts)
  -- first shrinks inner quantification
  --MkRose x (ts ++ map joinRose tts)

instance Functor Rose where
  -- f must be total
  fmap f (IORose rs)   = IORose (fmap (fmap f) rs)
  fmap f (MkRose x rs) = MkRose (f x) [ fmap f r | r <- rs ]

instance Monad Rose where
  return x = MkRose x []
  -- k must be total
  m >>= k  = joinRose (fmap k m)

-- Execute the "IORose" bits of a rose tree, returning a tree
-- constructed by MkRose.
reduceRose :: Rose Result -> IO (Rose Result)
reduceRose r@(MkRose _ _) = return r
reduceRose (IORose m) = m >>= reduceRose

-- Apply a function to the outermost MkRose constructor of a rose tree.
-- The function must be total!
onRose :: (a -> [Rose a] -> Rose a) -> Rose a -> Rose a
onRose f (MkRose x rs) = f x rs
onRose f (IORose m) = IORose (fmap (onRose f) m)

-- Wrap a rose tree in an exception handler.
protectRose :: IO (Rose Result) -> IO (Rose Result)
protectRose = protect (return . exception "Exception")

-- Wrap all the Results in a rose tree in exception handlers.
protectResults :: Rose Result -> Rose Result
protectResults = onRose $ \x rs ->
  IORose $ do
    y <- protectResult (return x)
    return (MkRose y (map protectResults rs))

-- ** Result type

-- | Different kinds of callbacks
data Callback
  = PostTest CallbackKind (State -> Result -> IO ())         -- ^ Called just after a test
  | PostFinalFailure CallbackKind (State -> Result -> IO ()) -- ^ Called with the final failing test-case
data CallbackKind = Counterexample    -- ^ Affected by the 'verbose' combinator
                  | NotCounterexample -- ^ Not affected by the 'verbose' combinator

-- | The result of a single test.
data Result
  = MkResult
  { ok          :: Maybe Bool     -- ^ result of the test case; Nothing = discard
  , expect      :: Bool           -- ^ indicates what the expected result of the property is
  , reason      :: String         -- ^ a message indicating what went wrong
  , interrupted :: Bool           -- ^ indicates if the test case was cancelled by pressing ^C
  , stamp       :: [(String,Int)] -- ^ the collected values for this test case
  , callbacks   :: [Callback]     -- ^ the callbacks for this test case
  }

result :: Result
result =
  MkResult
  { ok          = undefined
  , expect      = True
  , reason      = ""
  , interrupted = False
  , stamp       = []
  , callbacks   = []
  }

exception :: String -> AnException -> Result
exception msg err = failed{ reason = msg ++ ": '" ++ showErr err ++ "'",
                            interrupted = isInterrupt err }

protectResult :: IO Result -> IO Result
protectResult = protect (exception "Exception")

succeeded :: Result 
succeeded = result{ ok = Just True }

failed :: Result
failed = result{ ok = Just False }

rejected :: Result
rejected = result{ ok = Nothing }

--------------------------------------------------------------------------
-- ** Lifting and mapping functions

liftBool :: Bool -> Result
liftBool True = succeeded
liftBool False = failed { reason = "Falsifiable" }

mapResult :: Testable prop => (Result -> Result) -> prop -> Property
mapResult f = mapRoseResult (protectResults . fmap f)

mapTotalResult :: Testable prop => (Result -> Result) -> prop -> Property
mapTotalResult f = mapRoseResult (fmap f)

-- f here mustn't throw an exception (rose tree invariant).
mapRoseResult :: Testable prop => (Rose Result -> Rose Result) -> prop -> Property
mapRoseResult f = mapProp (\(MkProp t) -> MkProp (f t))

mapProp :: Testable prop => (Prop -> Prop) -> prop -> Property
mapProp f = fmap f . property

--------------------------------------------------------------------------
-- ** Property combinators

-- | Changes the maximum test case size for a property.
mapSize :: Testable prop => (Int -> Int) -> prop -> Property
mapSize f p = sized ((`resize` property p) . f)

-- | Shrinks the argument to property if it fails. Shrinking is done
-- automatically for most types. This is only needed when you want to
-- override the default behavior.
shrinking :: Testable prop =>
             (a -> [a])  -- ^ 'shrink'-like function.
          -> a           -- ^ The original argument
          -> (a -> prop) -> Property
shrinking shrinker x0 pf = fmap (MkProp . joinRose . fmap unProp) (promote (props x0))
 where
  props x =
    MkRose (property (pf x)) [ props x' | x' <- shrinker x ]

-- | Disables shrinking for a property altogether.
noShrinking :: Testable prop => prop -> Property
noShrinking = mapRoseResult (onRose (\res _ -> MkRose res []))

-- | Adds a callback
callback :: Testable prop => Callback -> prop -> Property
callback cb = mapTotalResult (\res -> res{ callbacks = cb : callbacks res })

-- | Prints a message to the terminal as part of the counterexample.
printTestCase :: Testable prop => String -> prop -> Property
printTestCase s =
  callback $ PostFinalFailure Counterexample $ \st _res ->
    putLine (terminal st) s

-- | Performs an 'IO' action after the last failure of a property.
whenFail :: Testable prop => IO () -> prop -> Property
whenFail m =
  callback $ PostFinalFailure NotCounterexample $ \_st _res ->
    m

-- | Performs an 'IO' action every time a property fails. Thus,
-- if shrinking is done, this can be used to keep track of the 
-- failures along the way.
whenFail' :: Testable prop => IO () -> prop -> Property
whenFail' m =
  callback $ PostTest NotCounterexample $ \_st res ->
    if ok res == Just False
      then m
      else return ()

-- | Prints out the generated testcase every time the property is tested,
-- like 'verboseCheck' from QuickCheck 1.
-- Only variables quantified over /inside/ the 'verbose' are printed.
verbose :: Testable prop => prop -> Property
verbose = mapResult (\res -> res { callbacks = newCallbacks (callbacks res) ++ callbacks res })
  where newCallbacks cbs =
          PostTest Counterexample (\st res -> putLine (terminal st) (status res ++ ":")):
          [ PostTest Counterexample f | PostFinalFailure Counterexample f <- cbs ]
        status MkResult{ok = Just True} = "Passed"
        status MkResult{ok = Just False} = "Failed"
        status MkResult{ok = Nothing} = "Skipped (precondition false)"

-- | Modifies a property so that it is expected to fail for some test cases.
expectFailure :: Testable prop => prop -> Property
expectFailure = mapTotalResult (\res -> res{ expect = False })

-- | Attaches a label to a property. This is used for reporting
-- test case distribution.
label :: Testable prop => String -> prop -> Property
label s = classify True s

-- | Labels a property with a value:
--
-- > collect x = label (show x)
collect :: (Show a, Testable prop) => a -> prop -> Property
collect x = label (show x)

-- | Conditionally labels test case.
classify :: Testable prop => 
            Bool    -- ^ @True@ if the test case should be labelled.
         -> String  -- ^ Label.
         -> prop -> Property
classify b s = cover b 0 s

-- | Checks that at least the given proportion of the test cases belong
-- to the given class.
cover :: Testable prop => 
         Bool   -- ^ @True@ if the test case belongs to the class.
      -> Int    -- ^ The required percentage (0-100) of test cases.
      -> String -- ^ Label for the test case class.
      -> prop -> Property
cover True n s = n `seq` s `listSeq` (mapTotalResult $ \res -> res { stamp = (s,n) : stamp res })
  where [] `listSeq` z = z
        (x:xs) `listSeq` z = x `seq` xs `listSeq` z
cover False _ _ = property

-- | Implication for properties: The resulting property holds if
-- the first argument is 'False', or if the given property holds.
(==>) :: Testable prop => Bool -> prop -> Property
False ==> _ = property ()
True  ==> p = property p

-- | Considers a property failed if it does not complete within
-- the given number of microseconds.
within :: Testable prop => Int -> prop -> Property
within n = mapRoseResult f
  -- We rely on the fact that the property will catch the timeout
  -- exception and turn it into a failed test case.
  where
    f rose = ioRose $ do
      let m `orError` x = fmap (fromMaybe (error x)) m
      MkRose res roses <- timeout n (reduceRose rose) `orError`
                          "within: timeout exception not caught in Rose Result"
      res' <- timeout n (protectResult (return res)) `orError`
              "within: timeout exception not caught in Result"
      return (MkRose res' (map f roses))
#ifdef NO_TIMEOUT
    timeout _ = fmap Just
#endif

-- | Explicit universal quantification: uses an explicitly given
-- test case generator.
forAll :: (Show a, Testable prop)
       => Gen a -> (a -> prop) -> Property
forAll gen pf =
  gen >>= \x ->
    printTestCase (show x) (pf x)

-- | Like 'forAll', but tries to shrink the argument for failing test cases.
forAllShrink :: (Show a, Testable prop)
             => Gen a -> (a -> [a]) -> (a -> prop) -> Property
forAllShrink gen shrinker pf =
  gen >>= \x ->
    shrinking shrinker x $ \x' ->
      printTestCase (show x') (pf x')

-- | Nondeterministic choice: 'p1' '.&.' 'p2' picks randomly one of
-- 'p1' and 'p2' to test. If you test the property 100 times it
-- makes 100 random choices.
(.&.) :: (Testable prop1, Testable prop2) => prop1 -> prop2 -> Property
p1 .&. p2 =
  arbitrary >>= \b ->
    printTestCase (if b then "LHS" else "RHS") $
      if b then property p1 else property p2

-- | Conjunction: 'p1' '.&&.' 'p2' passes if both 'p1' and 'p2' pass.
(.&&.) :: (Testable prop1, Testable prop2) => prop1 -> prop2 -> Property
p1 .&&. p2 = conjoin [property p1, property p2]

-- | Take the conjunction of several properties.
conjoin :: Testable prop => [prop] -> Property
conjoin ps = 
  do roses <- mapM (fmap unProp . property) ps
     return (MkProp (conj [] roses))
 where
  conj cbs [] =
    MkRose succeeded{callbacks = cbs} []

  conj cbs (p : ps) = IORose $ do
    rose@(MkRose result _) <- reduceRose p
    case ok result of
      _ | not (expect result) ->
        return (return failed { reason = "expectFailure may not occur inside a conjunction" })
      Just True -> return (conj (cbs ++ callbacks result) ps)
      Just False -> return rose
      Nothing -> do
        rose2@(MkRose result2 _) <- reduceRose (conj (cbs ++ callbacks result) ps)
        return $
          -- Nasty work to make sure we use the right callbacks
          case ok result2 of
            Just True -> MkRose (result2 { ok = Nothing }) []
            Just False -> rose2
            Nothing -> rose2

-- | Disjunction: 'p1' '.||.' 'p2' passes unless 'p1' and 'p2' simultaneously fail.
(.||.) :: (Testable prop1, Testable prop2) => prop1 -> prop2 -> Property
p1 .||. p2 = disjoin [property p1, property p2]

-- | Take the disjunction of several properties.
disjoin :: Testable prop => [prop] -> Property
disjoin ps = 
  do roses <- mapM (fmap unProp . property) ps
     return (MkProp (foldr disj (MkRose failed []) roses))
 where
  disj :: Rose Result -> Rose Result -> Rose Result
  disj p q =
    do result1 <- p
       case ok result1 of
         _ | not (expect result1) -> return expectFailureError
         Just True -> return result1
         Just False -> do
           result2 <- q
           return $
             if expect result2 then
               case ok result2 of
                 Just True -> result2
                 Just False -> result1 >>> result2
                 Nothing -> result2
             else expectFailureError
         Nothing -> do
           result2 <- q
           return (case ok result2 of
                     _ | not (expect result2) -> expectFailureError
                     Just True -> result2
                     _ -> result1)

  expectFailureError = failed { reason = "expectFailure may not occur inside a disjunction" }
  result1 >>> result2 | not (expect result1 && expect result2) = expectFailureError
  result1 >>> result2 =
    result2
    { reason      = if null (reason result2) then reason result1 else reason result2
    , interrupted = interrupted result1 || interrupted result2
    , stamp       = stamp result1 ++ stamp result2
    , callbacks   = callbacks result1 ++
                    [PostFinalFailure Counterexample $ \st _res -> putLine (terminal st) ""] ++
                    callbacks result2
    }

--------------------------------------------------------------------------
-- the end.
