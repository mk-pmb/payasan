{-# LANGUAGE DeriveDataTypeable         #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.IRSimpleTile.Syntax
-- Copyright   :  (c) Stephen Tetley 2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Simple tiled syntax - immediate form between External and
-- IREventBeam.
--
-- This syntax is intended to simplify joining tied notes 
-- and "time stealing" for grace notes.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.IRSimpleTile.Syntax
  ( 
    Part(..)
  , Section(..)
  , Bar(..)
  , Element(..)

  , elementLengthSymbolic
  , barDuration
  , elementDuration
  
  ) where


-- import Payasan.PSC.Base.SyntaxCommon
import Payasan.Base.Basis


import Data.Data

-- Design note
-- This syntax is designed to support a simple implmentation of 
-- joining tied notes.
-- 
-- Requirement - ties can span bars (must be able to coalesce 
-- them); ties cannot span sections.
-- 
-- A tie is a property of a symbolic representation - it goes 
-- some way towards the construction of arbitrary durations.
-- Events are thought of as discreet (singular) so the notion 
-- of joining events feels wrong.
-- Thus it makes sense to perform tie-joining on a note list 
-- rather than an event list. 
--
-- We simplify the syntax - because we represent duration by 
-- Seconds we can: 
--
-- Remove tuplets (we can calculate scale note durations).
--
-- Coalesce ties (we can add arbitrary durations)
-- 
-- "Time steal" for grace notes from their sucessor.
--
-- Remove meter indications from Bar headers (metrical info is
-- already accounted for in calculating duration).
-- 
-- We can also: 
--
-- Get rid of beams (beams are considered to be just a reading 
-- aid).
--
-- Unify Skips, Rests and Spacers (rendering/audition is 
-- oblivious to their differences).
--
-- Remove punctuation (rendering is oblivious to punctuation).
--

data Part pch anno = Part 
    { part_sections :: [Section pch anno] 
    }
  deriving (Data,Eq,Show,Typeable)

-- TODO - should we cache onsets in the syntax?
-- This ought to alleviate some of the problems with ordering 
-- steps of the outward transformation.


-- | We keep section in this syntax. Having named sections is
-- expected to allow transformations limited to a specific region.
--
data Section pch anno = Section 
    { section_name      :: !String
    , section_onset     :: !Seconds
    , section_bars      :: [Bar pch anno]
    }
  deriving (Data,Eq,Show,Typeable)
  
  
data Bar pch anno = Bar
    { bar_onset         :: !Seconds
    , bar_elems         :: [Element pch anno]
    }
  deriving (Data,Eq,Show,Typeable)

-- Note - ties cannot be seen by an elementary traversal (e.g. map), 
-- you have to look at the rest of input to see if a note is tied.  
data Element pch anno = 
      Note      Seconds pch   anno
    | Rest      Seconds
    | Chord     Seconds [pch] anno
    | Graces    [(Seconds,pch)]
    | TiedCont  Seconds
  deriving (Data,Eq,Show,Typeable)

  
  
-- | Note - graces have zero length.  
elementLengthSymbolic :: Element pch anno -> Seconds
elementLengthSymbolic (Note d _ _)  = d
elementLengthSymbolic (Rest d)      = d
elementLengthSymbolic (Chord d _ _) = d
elementLengthSymbolic (Graces {})   = 0
elementLengthSymbolic (TiedCont d)  = d


barDuration :: Bar pch anno -> Seconds
barDuration (Bar { bar_elems = bs }) = sum $ map elementDuration bs

-- | Note - graces have a combined length.  
--
elementDuration :: Element pch anno -> Seconds
elementDuration (Note d _ _)    = d
elementDuration (Rest d)        = d
elementDuration (Chord d _ _)   = d
elementDuration (Graces xs)     = sum $ map fst xs
elementDuration (TiedCont d)    = d


