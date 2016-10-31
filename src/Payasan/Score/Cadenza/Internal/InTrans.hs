{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Score.Cadenza.Internal.InTrans
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Convert LilyPond to (standard) Cadenza syntax.
--
--------------------------------------------------------------------------------

module Payasan.Score.Cadenza.Internal.InTrans
  (

    lilyPondTranslate_Relative
  , lilyPondTranslate_Absolute

  , trafoRelPitch
  , trafoAbsPitch
  , trafoDuration

  ) where



import Payasan.Score.Cadenza.Internal.Syntax
import Payasan.Score.Cadenza.Internal.Traversals

import Payasan.PSC.Base.LilyPondCommon
import Payasan.PSC.Base.RewriteMonad

import Payasan.Base.Duration
import Payasan.Base.Pitch



lilyPondTranslate_Relative :: Pitch
                           -> LyCadenzaPart2 LyPitch anno 
                           -> StdCadenzaPart1 anno
lilyPondTranslate_Relative pch = trafoRelPitch pch . trafoDuration


lilyPondTranslate_Absolute :: LyCadenzaPart2 LyPitch anno 
                           -> StdCadenzaPart1 anno
lilyPondTranslate_Absolute = trafoAbsPitch . trafoDuration


type DMon a    = Mon Duration a
type RelPMon a = Mon Pitch a
type AbsPMon a = Mon () a



--------------------------------------------------------------------------------
-- Relative Pitch translation

trafoRelPitch :: Pitch -> Part LyPitch drn anno -> Part Pitch drn anno
trafoRelPitch p0 = transformP (rel_pch_algo p0)

rel_pch_algo :: Pitch -> CadenzaPitchAlgo Pitch LyPitch Pitch
rel_pch_algo start = CadenzaPitchAlgo
    { initial_stateP    = start
    , element_trafoP    = relElementP
    }


previousPitch :: RelPMon Pitch
previousPitch = get

setPrevPitch :: Pitch -> RelPMon ()
setPrevPitch = put 


relElementP :: Element LyPitch drn anno -> RelPMon (Element Pitch drn anno)
relElementP (Note p d a t)      = (\p1 -> Note p1 d a t) <$> changePitchRel p
relElementP (Rest d)            = pure $ Rest d
relElementP (Spacer d)          = pure $ Spacer d
relElementP (Skip d)            = pure $ Skip d
relElementP (Punctuation s)     = pure $ Punctuation s



changePitchRel :: LyPitch -> RelPMon Pitch
changePitchRel p1 = 
    do { p0 <- previousPitch
       ; let tp1 = toPitchRel p0 p1
       ; setPrevPitch tp1
       ; return tp1
       }
                              



--------------------------------------------------------------------------------
-- Abs Pitch translation

trafoAbsPitch :: Part LyPitch drn anno -> Part Pitch drn anno
trafoAbsPitch = transformP abs_pch_algo


abs_pch_algo :: CadenzaPitchAlgo () LyPitch Pitch
abs_pch_algo = CadenzaPitchAlgo
    { initial_stateP    = ()
    , element_trafoP    = absElementP
    }


absElementP :: Element LyPitch drn anno -> AbsPMon (Element Pitch drn anno)
absElementP (Note p d a t)      = (\p1 -> Note p1 d a t) <$> changePitchAbs p
absElementP (Rest d)            = pure $ Rest d
absElementP (Spacer d)          = pure $ Spacer d
absElementP (Skip d)            = pure $ Skip d
absElementP (Punctuation s)     = pure $ Punctuation s


changePitchAbs :: LyPitch -> AbsPMon Pitch
changePitchAbs p1 = return $ toPitchAbs p1




--------------------------------------------------------------------------------
-- Duration translation

trafoDuration :: Part pch LyNoteLength anno -> Part pch Duration anno
trafoDuration = transformD drn_algo


drn_algo :: CadenzaDurationAlgo Duration LyNoteLength Duration 
drn_algo = CadenzaDurationAlgo
    { initial_stateD    = d_quarter
    , element_trafoD    = elementD
    }

previousDuration :: DMon Duration
previousDuration = get

setPrevDuration :: Duration -> DMon ()
setPrevDuration d = put d


elementD :: Element pch LyNoteLength anno -> DMon (Element pch Duration anno)
elementD (Note p d a t)         = (\d1 -> Note p d1 a t) <$> changeDuration d
elementD (Rest d)               = Rest   <$> changeDuration d
elementD (Spacer d)             = Spacer <$> changeDuration d
elementD (Skip d)               = Skip   <$> skipDuration d
elementD (Punctuation s)        = pure $ Punctuation s


changeDuration :: LyNoteLength -> DMon Duration
changeDuration (DrnDefault)         = previousDuration
changeDuration (DrnExplicit d)      = setPrevDuration d >> return d

skipDuration :: LyNoteLength -> DMon Duration
skipDuration (DrnDefault)           = previousDuration
skipDuration (DrnExplicit d)        = return d

