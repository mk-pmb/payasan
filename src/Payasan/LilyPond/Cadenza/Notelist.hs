{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.LilyPond.Cadenza.Notelist
-- Copyright   :  (c Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Cadenza for LilyPond.
--
--------------------------------------------------------------------------------

module Payasan.LilyPond.Cadenza.Notelist
  ( 

    module Payasan.Base.Internal.Shell
   
  , StdCadenzaPhrase
  , cadenza

  , ScoreInfo(..)        -- Re-export
  , default_score_info


  , LocalContextInfo(..)         -- Re-export
  , UnitNoteLength(..)
  , default_local_info

  , fromLilyPond_Relative
  , fromLilyPondWith_Relative

  , genOutputAsLilyPond

  , outputAsLilyPond_Relative
  , printAsLilyPond_Relative

  ) where

import Payasan.LilyPond.Cadenza.Internal.CadenzaToBeam
import Payasan.LilyPond.Cadenza.Internal.InTrans
import Payasan.LilyPond.Cadenza.Internal.Parser
import Payasan.LilyPond.Cadenza.Internal.Syntax


import qualified Payasan.Base.Internal.LilyPond.OutTrans        as LY
import qualified Payasan.Base.Internal.LilyPond.SimpleOutput    as LY
import qualified Payasan.Base.Internal.LilyPond.Utils           as PP

import Payasan.Base.Internal.AddBeams (noBeams)
import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.Pipeline (LilyPondPipeline(..))
import qualified Payasan.Base.Internal.Pipeline                 as MAIN
import Payasan.Base.Internal.Shell

import Payasan.Base.Pitch

import Text.PrettyPrint.HughesPJClass           -- package: pretty



fromLilyPond_Relative :: Pitch 
                      -> LyCadenzaPhrase1 anno 
                      -> StdCadenzaPhrase1 anno
fromLilyPond_Relative pch = fromLilyPondWith_Relative pch default_local_info

fromLilyPondWith_Relative :: Pitch  
                          -> LocalContextInfo
                          -> LyCadenzaPhrase1 anno
                          -> StdCadenzaPhrase1 anno
fromLilyPondWith_Relative pch locals = 
    lilyPondTranslate_Relative pch . pushContextInfo (locals { local_meter = Unmetered })



genOutputAsLilyPond :: LilyPondPipeline p1i a1i p1o a1o
                    -> StdCadenzaPhrase2 p1i a1i
                    -> Doc
genOutputAsLilyPond config = 
    outputStep . toGenLyPhrase . beamingRewrite . translateToBeam
  where
    beamingRewrite      = beam_trafo config
    toGenLyPhrase       = out_trafo config
    outputStep          = output_func config



outputAsLilyPond_Relative :: Anno anno 
                          => ScoreInfo -> Pitch -> StdCadenzaPhrase1 anno -> String
outputAsLilyPond_Relative infos pch = MAIN.ppRender . genOutputAsLilyPond config
  where
    config  = LilyPondPipeline { beam_trafo  = noBeams
                               , out_trafo   = LY.translateToOutput_Relative pch
                               , output_func = LY.simpleScore_Relative std_def infos pch
                               }
    std_def = LY.LyOutputDef { LY.printPitch = PP.pitch, LY.printAnno = anno }

printAsLilyPond_Relative :: Anno anno 
                => ScoreInfo -> Pitch -> StdCadenzaPhrase1 anno -> IO ()
printAsLilyPond_Relative globals pch = 
    putStrLn . outputAsLilyPond_Relative globals pch
