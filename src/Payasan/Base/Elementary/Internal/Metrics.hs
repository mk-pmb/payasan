{-# LANGUAGE ScopedTypeVariables        #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Elementary.Internal.Metrics
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Metrics  - barcount, lowest pitch, highest pitch...
--
-- Contours.
--
--------------------------------------------------------------------------------

module Payasan.Base.Elementary.Internal.Metrics
  (

    barCount
  , pitchHisto
  , pitchNameHisto
  , octaveHisto

  , firstPitch
  , lastPitch
  , lowestPitch
  , highestPitch

  , lowestDiatonic
  , highestDiatonic

  , semitoneInterval

  , grossContour

  , refinedContour


  ) where


import Payasan.Base.Elementary.Internal.Syntax
import Payasan.Base.Elementary.Internal.Traversals

import Payasan.Base.Internal.AnalysisCommon
import Payasan.Base.Internal.AnalysisTrace
import Payasan.Base.Internal.Base

import Payasan.Base.Pitch
import Payasan.Base.Diatonic






-- Simple metrics

barCount :: Part pch drn anno -> Int
barCount (Part { part_bars = bs }) = length bs




-- histograms 

pitchHisto :: Part Pitch drn anno -> Histogram Pitch
pitchHisto = accumPitch (\ac p -> incr p ac) empty


pitchNameHisto :: Part Pitch drn anno -> Histogram PitchName
pitchNameHisto = accumPitch (\ac p -> incr (pitch_name p) ac) empty


octaveHisto :: Part Pitch drn anno -> Histogram Int
octaveHisto = accumPitch fn empty
  where
    fn histo p = incr (pitch_octave p) histo


firstPitch :: Part pch drn anno -> Maybe pch
firstPitch = accumStop (\ac e -> fn ac e) Nothing
  where 
    fn _  (Note p _ _ _) = Stop (Just p)
    fn ac _              = Go ac



lastPitch :: Part pch drn anno -> Maybe pch
lastPitch = accumPitch fn Nothing
  where
    fn _ p = Just p

lowestPitch :: Part Pitch drn anno -> Maybe Pitch
lowestPitch = accumPitch fn Nothing
  where
    fn Nothing   p                      = Just p
    fn (Just p0) p | p `isLower` p0     = Just p
                   | otherwise          = Just p0

highestPitch :: Part Pitch drn anno -> Maybe Pitch
highestPitch = accumPitch fn Nothing
  where
    fn Nothing   p                      = Just p
    fn (Just p0) p | p `isHigher` p0    = Just p
                   | otherwise          = Just p0

lowestDiatonic :: Part Diatonic drn anno -> Maybe Diatonic
lowestDiatonic = fmap nubAlteration . accumPitch fn Nothing
  where
    fn Nothing   s = Just s
    fn (Just s0) s = if diatonicIndex s < diatonicIndex s0 then Just s else Just s0


highestDiatonic :: Part Diatonic drn anno -> Maybe Diatonic
highestDiatonic = fmap nubAlteration . accumPitch fn Nothing
  where
    fn Nothing   s = Just s
    fn (Just s0) s = if diatonicIndex s > diatonicIndex s0 then Just s else Just s0



--------------------------------------------------------------------------------
-- Contours

contourStep :: (Pitch -> Pitch -> ctour) 
            -> (Maybe Pitch -> Element Pitch d a -> (Maybe Pitch, TraceElement ctour))
contourStep fn (Just p0) (Note p _ _ _) = (Just p, Element $ fn p0 p)
contourStep _  Nothing   (Note p _ _ _) = (Just p, Blank)
contourStep _  st        _              = (st, Blank)



semitoneInterval :: Part Pitch drn anno -> TracePart Int
semitoneInterval = snd . intoTraceAccum (contourStep comp) Nothing
  where
    comp pold pnew = let sc = interval_semitones $ intervalBetween pold pnew
                     in if pnew `isLower` pold then negate sc else sc


grossContour :: Part Pitch drn anno -> TracePart GrossContour
grossContour = snd . intoTraceAccum (contourStep comp) Nothing
  where
    comp pold pnew | pnew `isHigher` pold = UP
                   | pnew `isLower`  pold = DOWN
                   | otherwise            = GROSS_SAME




refinedContour :: Part Pitch drn anno -> TracePart RefinedContour
refinedContour = snd . intoTraceAccum (contourStep comp) Nothing
  where
    comp pold pnew 
        | pnew `isHigher` pold = let ival = intervalBetween pold pnew
                                 in if interval_distance ival > 2 
                                    then LEAP_UP else STEP_UP

        | pnew `isLower`  pold = let ival = intervalBetween pnew pold
                                 in if interval_distance ival > 2 
                                    then LEAP_DOWN else STEP_DOWN

        | otherwise            = REFINED_SAME


