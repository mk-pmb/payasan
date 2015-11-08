{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.MIDI.BeamToMIDI
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Convert Beam syntax to MIDI syntax.
-- 
--------------------------------------------------------------------------------

module Payasan.Base.Internal.MIDI.BeamToMIDI
  ( 

    translateToMIDI

  ) where

import qualified Payasan.Base.Internal.MIDI.PrimitiveSyntax     as T

import Payasan.Base.Internal.Base
import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.RewriteMonad
import Payasan.Base.Internal.TiedNoteStream

import Payasan.Base.Duration


-- | Translate should operate on: 
--
-- > Phrase T.MidiPitch Duration
-- 
-- Rather than:
--
-- > Phrase T.Pitch Duration
-- 
-- So we can handle MIDI drums
--


type Mon a = Rewrite Seconds a


translateToMIDI :: T.TrackData -> Phrase T.MidiPitch Duration anno -> T.Track
translateToMIDI td ph = T.Track $ evalRewrite (phraseT td ph) 0


-- Work in seconds rather than MIDI ticks at this stage.
-- It will be easier with seconds to extend with quantization
-- (swing).



advanceOnset :: Seconds -> Mon ()
advanceOnset d = puts (\s -> s+d)

onset :: Mon Seconds
onset = get

phraseT :: T.TrackData -> Phrase T.MidiPitch Duration anno -> Mon T.InterimTrack
phraseT td ph = 
    (\ns -> T.InterimTrack { T.track_config = td
                           , T.track_notes  = concat ns
                           })
        <$> mapM elementT (makeTiedNoteStream ph)
 


-- Ties have been coalesced at this point...
--
elementT :: Element T.MidiPitch Seconds anno -> Mon [T.MidiNote]
elementT (NoteElem e _ _)       = (\x -> [x]) <$> noteT e

elementT (Rest d)               = 
    do { advanceOnset d
       ; return []
       }

-- MIDI: Spacer is same as Rest
elementT (Spacer d)             = 
    do { advanceOnset d
       ; return []
       }

-- MIDI: Skip is same as Rest
elementT (Skip d)               = 
    do { advanceOnset d
       ; return []
       }

elementT (Chord ps d _ _)       = 
    do { ot <- onset
       ; advanceOnset d
       ; return $ map (makeNote ot d) ps
       }

elementT (Graces {})            = return []

elementT (Punctuation {})       = return []


noteT :: Note T.MidiPitch Seconds -> Mon T.MidiNote
noteT (Note pch drn)            = 
    do { ot <- onset
       ; advanceOnset drn
       ; return $ makeNote ot drn pch
       }



-- TODO should have some individual control over velocities.
--
makeNote :: Seconds -> Seconds -> T.MidiPitch -> T.MidiNote
makeNote ot d p = T.MidiNote 
    { T.note_start    = ot
    , T.note_dur      = d
    , T.note_value    = T.NoteValue { T.note_pitch = p
                                    , T.note_velo_on  = 127
                                    , T.note_velo_off = 0
                                    }
    }


