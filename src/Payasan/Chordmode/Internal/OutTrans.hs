{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Chordmode.Internal.OutTrans
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- (Pipeline)
--
--------------------------------------------------------------------------------

module Payasan.Chordmode.Internal.OutTrans
  ( 
    translateOutput      -- name problem
  ) where

import Payasan.Chordmode.Internal.Base
import Payasan.Base.Monophonic.Internal.MonoPitchAnnoTrafo
import Payasan.Base.Monophonic.Internal.Syntax as MONO

import qualified Payasan.Base.Internal.LilyPond.Syntax as LY
import Payasan.Base.Internal.LilyPond.Utils

translateOutput :: MONO.Phrase Chord drn anno -> MONO.Phrase LY.Pitch drn ChordSuffix
translateOutput = trafoAnnos 

trafoAnnos :: MONO.Phrase Chord drn anno -> MONO.Phrase LY.Pitch drn ChordSuffix
trafoAnnos = mapPitchAnno $ \ch _ -> (fromPitchAbs $ chord_root ch, chord_suffix ch)