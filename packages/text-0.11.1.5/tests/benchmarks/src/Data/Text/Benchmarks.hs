-- | Main module to run the micro benchmarks
--
{-# LANGUAGE OverloadedStrings #-}
module Main
    ( main
    ) where

import Criterion.Main (Benchmark, defaultMain, bgroup)
import System.FilePath ((</>))
import System.IO (IOMode (WriteMode), openFile, hSetEncoding, utf8)

import qualified Data.Text.Benchmarks.Builder as Builder
import qualified Data.Text.Benchmarks.DecodeUtf8 as DecodeUtf8
import qualified Data.Text.Benchmarks.EncodeUtf8 as EncodeUtf8
import qualified Data.Text.Benchmarks.Equality as Equality
import qualified Data.Text.Benchmarks.FileRead as FileRead
import qualified Data.Text.Benchmarks.FoldLines as FoldLines
import qualified Data.Text.Benchmarks.Pure as Pure
import qualified Data.Text.Benchmarks.ReadNumbers as ReadNumbers
import qualified Data.Text.Benchmarks.Replace as Replace
import qualified Data.Text.Benchmarks.Search as Search
import qualified Data.Text.Benchmarks.WordFrequencies as WordFrequencies

import qualified Data.Text.Benchmarks.Programs.BigTable as Programs.BigTable
import qualified Data.Text.Benchmarks.Programs.Cut as Programs.Cut
import qualified Data.Text.Benchmarks.Programs.Fold as Programs.Fold
import qualified Data.Text.Benchmarks.Programs.Sort as Programs.Sort
import qualified Data.Text.Benchmarks.Programs.StripTags as Programs.StripTags
import qualified Data.Text.Benchmarks.Programs.Throughput as Programs.Throughput

main :: IO ()
main = benchmarks >>= defaultMain

benchmarks :: IO [Benchmark]
benchmarks = do
    sink <- openFile "/dev/null" WriteMode
    hSetEncoding sink utf8

    -- Traditional benchmarks
    bs <- sequence
        [ Builder.benchmark
        , DecodeUtf8.benchmark "html" (tf "libya-chinese.html")
        , DecodeUtf8.benchmark "xml" (tf "yiwiki.xml")
        , DecodeUtf8.benchmark "ascii" (tf "ascii.txt")
        , DecodeUtf8.benchmark "russian" (tf "russian.txt")
        , DecodeUtf8.benchmark "japanese" (tf "japanese.txt")
        , EncodeUtf8.benchmark "επανάληψη 竺法蘭共譯"
        , Equality.benchmark (tf "japanese.txt")
        , FileRead.benchmark (tf "russian.txt")
        , FoldLines.benchmark (tf "russian.txt")
        , Pure.benchmark (tf "japanese.txt")
        , ReadNumbers.benchmark (tf "numbers.txt")
        , Replace.benchmark (tf "russian.txt") "принимая" "своем"
        , Search.benchmark (tf "russian.txt") "принимая"
        , WordFrequencies.benchmark (tf "russian.txt")
        ]

    -- Program-like benchmarks
    ps <- bgroup "Programs" `fmap` sequence
        [ Programs.BigTable.benchmark sink
        , Programs.Cut.benchmark (tf "russian.txt") sink 20 40
        , Programs.Fold.benchmark (tf "russian.txt") sink
        , Programs.Sort.benchmark (tf "russian.txt") sink
        , Programs.StripTags.benchmark (tf "yiwiki.xml") sink
        , Programs.Throughput.benchmark (tf "russian.txt") sink
        ]

    return $ bs ++ [ps]
  where
    -- Location of a test file
    tf = ("../text-test-data" </>)
