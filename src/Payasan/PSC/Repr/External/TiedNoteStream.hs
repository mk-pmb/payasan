{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.External.TiedNoteStream
-- Copyright   :  (c) Stephen Tetley 2015-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Coalesce tied notes (and chords) to make a note stream.
--
-- The result may not be symbolically printable, but it will be 
-- renderable to MIDI or Csound.
-- 
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.External.TiedNoteStream
  ( 

    makeTiedNoteStream

  ) where


import Payasan.PSC.Repr.External.Syntax
import Payasan.PSC.Base.SyntaxCommon

import Payasan.Base.Basis
import Payasan.Base.Duration

import Data.Ratio




--------------------------------------------------------------------------------
-- Coalesce tied notes and chords

-- First step linearize and turn duration to seconds
-- need to be in lear form to concat tied notes chords across 
-- bar lines / note groups



makeTiedNoteStream :: Eq pch 
                   => Part pch Duration anno -> [Element pch Seconds anno]
makeTiedNoteStream = coalesce . linearize


linearize :: Part pch Duration anno -> [Element pch Seconds anno]
linearize (Part ss) = concatMap linearizeS ss


linearizeS :: Section pch Duration anno -> [Element pch Seconds anno]
linearizeS (Section _ info bs) = 
    let bpm = 120 in concatMap (linearizeB bpm) bs

linearizeB :: BPM -> Bar pch Duration anno -> [Element pch Seconds anno]
linearizeB bpm (Bar cs) = concatMap (linearizeNG bpm) cs


linearizeNG :: BPM -> NoteGroup pch Duration anno -> [Element pch Seconds anno]
linearizeNG bpm (Atom e)            = [linearizeE bpm e]
linearizeNG bpm (Beamed es)         = concatMap (linearizeNG bpm) es
linearizeNG bpm (Tuplet spec es)    = map (scaleD (t%n)) $ concatMap (linearizeNG bpm) es
  where
    (TupletSpec t n _) = spec


linearizeE :: BPM -> Element pch Duration anno -> Element pch Seconds anno
linearizeE bpm (Note p d a t)       = Note p (noteDuration bpm d) a t
linearizeE bpm (Rest d)             = Rest $ noteDuration bpm d
linearizeE bpm (Spacer d)           = Spacer $ noteDuration bpm d
linearizeE bpm (Skip d)             = Skip $ noteDuration bpm d
linearizeE bpm (Chord ps d a t)     = Chord ps (noteDuration bpm d) a t
linearizeE bpm (Graces ns)          = Graces $ map (linearizeG1 bpm) ns
linearizeE _   (Punctuation s)      = Punctuation s


linearizeG1 :: BPM -> Grace1 pch Duration -> Grace1 pch Seconds
linearizeG1 bpm (Grace1 pch drn)    = Grace1 pch $ noteDuration bpm drn




-- Simplistic scaling of Tuplets - does this really work?
--
scaleD :: Ratio Int -> Element pch Seconds anno -> Element pch Seconds anno
scaleD sc elt = step (realToFrac sc) elt
  where
    step x (Note p d a t)       = Note p (x * d) a t
    step x (Rest d)             = Rest $ x * d
    step x (Spacer d)           = Spacer $ x * d
    step x (Skip d)             = Skip $ x * d
    step x (Chord ps d a t)     = Chord ps (x * d) a t
    step x (Graces ns)          = Graces $ map (grace1 x) ns
    step _ (Punctuation s)      = Punctuation s

    grace1 x (Grace1 p d)       = Grace1 p (x * d)



coalesce :: Eq pch => [Element pch Seconds anno] -> [Element pch Seconds anno]
coalesce []     = []
coalesce (x:xs) = step x xs
  where
    step a []     = [a]
    step a (b:bs) = case together a b of
                      Nothing -> a : step b bs
                      Just t -> step t bs


-- Join together notes or chords if tied (and have the same notes).
--
together :: Eq pch
         => Element pch Seconds anno 
         -> Element pch Seconds anno 
         -> Maybe (Element pch Seconds anno)
together (Note p1 d1 _ t1)     (Note p2 d2 a t2)    = 
    case together1 (p1,d1) (p2,d2) t1 of
      Just (pnew,dnew) -> Just $ Note pnew dnew a t2
      Nothing -> Nothing

together (Chord ps1 d1 _ TIE)   (Chord ps2 d2 a t)    = 
    if ps1 == ps2 then Just $ Chord ps2 (d1+d2) a t
                  else Nothing

together _                      _                     = Nothing



-- Together for notes...
--
together1 :: Eq pch
          => (pch, Seconds)
          -> (pch, Seconds)
          -> Tie 
          -> Maybe (pch,Seconds)
together1 (p1,d1) (p2,d2) t 
    | p1 == p2 && t == TIE   = Just $ (p1, d1+d2)
    | otherwise              = Nothing



noteDuration :: BPM -> Duration -> Seconds
noteDuration bpm d = 
    realToFrac (durationToRatDuration d) * (4 * quarterNoteDuration bpm)

quarterNoteDuration :: BPM -> Seconds
quarterNoteDuration bpm = realToFrac $ 60 / bpm
