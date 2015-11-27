{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.TiedNoteStream
-- Copyright   :  (c) Stephen Tetley 2015
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

module Payasan.Base.Internal.TiedNoteStream
  ( 

    makeTiedNoteStream

  ) where


import Payasan.Base.Internal.Base
import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.CommonSyntax

import Payasan.Base.Duration

import Data.Ratio




--------------------------------------------------------------------------------
-- Coalesce tied notes and chords

-- First step linearize and turn duration to seconds
-- need to be in lear form to concat tied notes chords across 
-- bar lines / note groups



makeTiedNoteStream :: Eq pch 
                   => Phrase pch Duration anno -> [Element pch Seconds anno]
makeTiedNoteStream = coalesce . linearize


linearize :: Phrase pch Duration anno -> [Element pch Seconds anno]
linearize (Phrase bs) = concatMap linearizeB bs

linearizeB :: Bar pch Duration anno -> [Element pch Seconds anno]
linearizeB (Bar info cs) = 
    let bpm = local_bpm info in concatMap (linearizeNG bpm) cs


linearizeNG :: BPM -> NoteGroup pch Duration anno -> [Element pch Seconds anno]
linearizeNG bpm (Atom e)            = [linearizeE bpm e]
linearizeNG bpm (Beamed es)         = concatMap (linearizeNG bpm) es
linearizeNG bpm (Tuplet spec es)    = map (scaleD (t%n)) $ concatMap (linearizeNG bpm) es
  where
    (TupletSpec t n _) = spec


linearizeE :: BPM -> Element pch Duration anno -> Element pch Seconds anno
linearizeE bpm (NoteElem e a t)     = NoteElem (linearizeN bpm e) a t
linearizeE bpm (Rest d)             = Rest $ noteDuration bpm d
linearizeE bpm (Spacer d)           = Spacer $ noteDuration bpm d
linearizeE bpm (Skip d)             = Skip $ noteDuration bpm d
linearizeE bpm (Chord ps d a t)     = Chord ps (noteDuration bpm d) a t
linearizeE bpm (Graces ns)          = Graces $ map (linearizeN bpm) ns
linearizeE _   (Punctuation s)      = Punctuation s


linearizeN :: BPM -> Note pch Duration -> Note pch Seconds
linearizeN bpm (Note pch drn)   = Note pch $ noteDuration bpm drn




-- Simplistic scaling of Tuplets - does this really work?
--
scaleD :: Ratio Int -> Element pch Seconds anno -> Element pch Seconds anno
scaleD sc elt = step (realToFrac sc) elt
  where
    step x (NoteElem n a t)     = NoteElem (note x n) a t
    step x (Rest d)             = Rest $ x * d
    step x (Spacer d)           = Spacer $ x * d
    step x (Skip d)             = Skip $ x * d
    step x (Chord ps d a t)     = Chord ps (x * d) a t
    step x (Graces ns)          = Graces $ map (note x) ns
    step _ (Punctuation s)      = Punctuation s

    note x (Note p d)           = Note p (x * d)



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
together (NoteElem n1 _ t1)     (NoteElem n2 a t2)    = 
    case together1 n1 n2 t1 of
      Just note -> Just $ NoteElem note a t2
      Nothing -> Nothing

together (Chord ps1 d1 _ TIE)   (Chord ps2 d2 a t)    = 
    if ps1 == ps2 then Just $ Chord ps2 (d1+d2) a t
                  else Nothing

together _                      _                     = Nothing



-- Together for notes...
--
together1 :: Eq pch
          => Note pch Seconds 
          -> Note pch Seconds 
          -> Tie 
          -> Maybe (Note pch Seconds)
together1 (Note p1 d1) (Note p2 d2) t 
    | p1 == p2 && t == TIE   = Just $ Note p1 (d1+d2)
    | otherwise              = Nothing



noteDuration :: BPM -> Duration -> Seconds
noteDuration bpm d = 
    realToFrac (toRDuration d) * (4 * quarterNoteDuration bpm)

quarterNoteDuration :: BPM -> Seconds
quarterNoteDuration bpm = realToFrac $ 60 / bpm