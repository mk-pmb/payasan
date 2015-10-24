{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.Pipeline
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

module Payasan.Base.Internal.Pipeline
  ( 

    StdPhrase
  , StdPhraseAnno

  , ABCPhrase           -- * re-export
  , abc                 -- * re-export

  , LyPhrase
  , lilypond

  , ScoreInfo(..)
  , default_score_info 

  , VoiceInfo(..)
  , OctaveMode(..)
  , default_voice_info 

  , LocalContextInfo(..)
  , UnitNoteLength(..)
  , default_local_info


  , fromABC
  , fromABCWith
  , fromABCWithIO       -- temp ?
  , fromLilyPond
  , fromLilyPondWith
  , fromLilyPondWithIO  -- temp ?
  
  , outputAsABC
  , printAsABC

  , LilyPondPipeline(..)
  , genOutputAsLilyPond

  , LilyPondPipeline2(..)
  , genOutputAsLilyPond2


  , outputAsLilyPond
  , printAsLilyPond

  , genOutputAsRhythmicMarkup
  , outputAsRhythmicMarkup
  , printAsRhythmicMarkup


  , ppRender

  , writeAsMIDI

  , outputAsTabular
  , printAsTabular

  , outputAsLinear
  , printAsLinear

  ) where

import qualified Payasan.Base.Internal.ABC.InTrans          as ABC
import qualified Payasan.Base.Internal.ABC.OutTrans         as ABC
import Payasan.Base.Internal.ABC.Output (abcOutput)
import Payasan.Base.Internal.ABC.Parser (abc)
import Payasan.Base.Internal.ABC.Syntax (ABCPhrase)

import qualified Payasan.Base.Internal.LilyPond.InTrans         as LY
import qualified Payasan.Base.Internal.LilyPond.RhythmicMarkup  as LY
import qualified Payasan.Base.Internal.LilyPond.OutTrans        as LY
import qualified Payasan.Base.Internal.LilyPond.SimpleOutput    as LY
import Payasan.Base.Internal.LilyPond.Quasiquote (lilypond)
import qualified Payasan.Base.Internal.LilyPond.Syntax          as LY
import Payasan.Base.Internal.LilyPond.Syntax (LyPhrase)
import Payasan.Base.Internal.LilyPond.Utils

import qualified Payasan.Base.Internal.MIDI.BeamToMIDI      as MIDI
import qualified Payasan.Base.Internal.MIDI.Output          as MIDI
import qualified Payasan.Base.Internal.MIDI.OutTrans        as MIDI
import qualified Payasan.Base.Internal.MIDI.PrimitiveSyntax as MIDI

import Payasan.Base.Internal.Output.Common
import Payasan.Base.Internal.Output.Tabular.OutputBeam
import Payasan.Base.Internal.Output.Tabular.OutputMain
import Payasan.Base.Internal.Output.Linear.OutputMain


import Payasan.Base.Internal.AddBeams
import qualified Payasan.Base.Internal.BeamSyntax           as BEAM
import Payasan.Base.Internal.BeamToMain
import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.MainToBeam
import Payasan.Base.Internal.MainSyntax




import Payasan.Base.Duration
import Payasan.Base.Pitch

import Text.PrettyPrint.HughesPJClass           -- package: pretty



type StdPhrase          = Phrase Pitch Duration () 
type StdPhraseAnno anno = Phrase Pitch Duration anno


--------------------------------------------------------------------------------
-- Writer monad for debugging / tracing

(<||>) :: Doc -> Doc -> Doc
a <||> b = a $+$ text "" $+$ b

-- | Writer monad to collect debug output, concat is (<||>).
--
newtype W a = W { getW :: (Doc,a) }

instance Functor W where
  fmap f ma = W $ let (w,a) = getW ma in (w,f a)

instance Applicative W where
  pure a    = W (empty, a)
  mf <*> ma = W $ let (w1,f) = getW mf
                      (w2,a) = getW ma
                  in (w1 <||> w2, f a)

instance Monad W where
  return    = pure
  ma >>= k  = W $ let (w1,a) = getW ma 
                      (w2,b) = getW (k a)
                  in (w1 <||> w2, b)
            
runW :: W a -> (Doc,a) 
runW = getW

tell :: Doc -> W ()
tell d = W $ (d,())                
  
debug :: (a -> Doc) -> a -> W a
debug f a = tell (f a) >> return a

--------------------------------------------------------------------------------
-- 

fromABC :: ABCPhrase -> StdPhrase
fromABC = fromABCWith default_local_info

fromABCWith :: LocalContextInfo -> ABCPhrase -> StdPhrase
fromABCWith locals = translateToMain . ABC.translateFromInput . BEAM.pushContextInfo locals


fromABCWithIO :: LocalContextInfo -> ABCPhrase -> IO StdPhrase
fromABCWithIO locals ph = 
    let (out,a) = runW body in do { putStrLn (ppRender out); return a }
  where
    body = do { ph1 <- debug (beamTabular std_abc_output) $ BEAM.pushContextInfo locals ph
              ; ph2 <- debug (beamTabular pitch_duration_output) $ ABC.translateFromInput ph1
              ; ph3 <- debug (mainTabular pitch_duration_output) $ translateToMain ph2
              ; return ph3
              }



fromLilyPond :: VoiceInfo -> LY.LyPhrase () -> StdPhrase 
fromLilyPond gi = fromLilyPondWith gi default_local_info


fromLilyPondWith :: VoiceInfo -> LocalContextInfo -> LY.LyPhrase () -> StdPhrase
fromLilyPondWith gi ri = 
    translateToMain . LY.translateFromInput gi . BEAM.pushContextInfo ri

fromLilyPondWithIO :: VoiceInfo 
                   -> LocalContextInfo 
                   -> LY.LyPhrase () 
                   -> IO StdPhrase
fromLilyPondWithIO gi ri ph = 
    let (out,a) = runW body in do { putStrLn (ppRender out); return a }
  where
    body = do { ph1 <- debug (beamTabular std_ly_output) $ BEAM.pushContextInfo ri ph
              ; ph2 <- debug (beamTabular pitch_duration_output) $ LY.translateFromInput gi ph1
              ; ph3 <- debug (mainTabular pitch_duration_output) $ translateToMain ph2
              ; return ph3
              }



outputAsABC :: ScoreInfo -> VoiceInfo -> StdPhraseAnno anno -> String
outputAsABC infos infov = 
    ppRender . abcOutput infos infov
             . ABC.translateToOutput
             . addBeams 
             . translateToBeam

printAsABC :: ScoreInfo -> VoiceInfo -> StdPhraseAnno anno -> IO ()
printAsABC infos infov = putStrLn . outputAsABC infos infov


-- | This can capture both full score output and just notelist 
-- output by supplying the appropriate output function.
--
-- Libraries should define two output functions when appropriate:
-- one for full score and one for just notelist.
--
data LilyPondPipeline p1i a1i p1o a1o = LilyPondPipeline
    { beam_trafo    :: BEAM.Phrase p1i Duration a1i -> BEAM.Phrase p1i Duration a1i
    , out_trafo     :: BEAM.Phrase p1i Duration a1i -> LY.GenLyPhrase p1o a1o
    , output_func   :: LY.GenLyPhrase p1o a1o -> Doc
    }




genOutputAsLilyPond :: LilyPondPipeline p1i a1i p1o a1o
                    -> Phrase p1i Duration a1i
                    -> Doc
genOutputAsLilyPond config = 
    outputStep . toGenLyPhrase . beamingRewrite . translateToBeam
  where
    beamingRewrite      = beam_trafo config
    toGenLyPhrase       = out_trafo config
    outputStep          = output_func config


data LilyPondPipeline2 p1i a1i p2i a2i p1o a1o p2o a2o  = LilyPondPipeline2
    { pipe2_beam_trafo1   :: BEAM.Phrase p1i Duration a1i -> BEAM.Phrase p1i Duration a1i
    , pipe2_out_trafo1    :: BEAM.Phrase p1i Duration a1i -> LY.GenLyPhrase p1o a1o
    , pipe2_beam_trafo2   :: BEAM.Phrase p2i Duration a2i -> BEAM.Phrase p2i Duration a2i
    , pipe2_out_trafo2    :: BEAM.Phrase p2i Duration a2i -> LY.GenLyPhrase p2o a2o
    , pipe2_output_func   :: LY.GenLyPhrase p1o a1o -> LY.GenLyPhrase p2o a2o -> Doc
    }



genOutputAsLilyPond2 :: LilyPondPipeline2 p1i a1i p2i a2i p1o a1o p2o a2o 
                     -> Phrase p1i Duration a1i
                     -> Phrase p2i Duration a2i
                     -> Doc
genOutputAsLilyPond2 config ph1 ph2 = 
    let a = toGenLyPhrase1 $ beamingRewrite1 $ translateToBeam ph1
        b = toGenLyPhrase2 $ beamingRewrite2 $ translateToBeam ph2
    in outputStep a b
  where
    beamingRewrite1     = pipe2_beam_trafo1 config
    toGenLyPhrase1      = pipe2_out_trafo1 config
    beamingRewrite2     = pipe2_beam_trafo2 config
    toGenLyPhrase2      = pipe2_out_trafo2 config
    outputStep          = pipe2_output_func config



outputAsLilyPond :: Anno anno 
                 => ScoreInfo -> VoiceInfo -> StdPhraseAnno anno -> String
outputAsLilyPond infos infov = ppRender . genOutputAsLilyPond config
  where
    config  = LilyPondPipeline { beam_trafo  = addBeams
                               , out_trafo   = LY.translateToOutput infov
                               , output_func = LY.simpleScore std_def infos infov
                               }
    std_def = LY.LyOutputDef { LY.printPitch = pitch, LY.printAnno = anno }


printAsLilyPond :: Anno anno 
                => ScoreInfo -> VoiceInfo -> StdPhraseAnno anno -> IO ()
printAsLilyPond infos infov = putStrLn . outputAsLilyPond infos infov



-- Rhythmic markup generally should be beamed.

genOutputAsRhythmicMarkup :: LY.MarkupOutput pch 
                          -> ScoreInfo
                          -> VoiceInfo
                          -> Phrase pch Duration anno 
                          -> Doc
genOutputAsRhythmicMarkup def infos infov = 
    LY.rhythmicMarkupScore ppDef infos infov . LY.translateToRhythmicMarkup def
                                             . addBeams 
                                             . translateToBeam
  where
    ppDef = LY.LyOutputDef { LY.printPitch = pitch, LY.printAnno = const empty }


outputAsRhythmicMarkup :: ScoreInfo -> VoiceInfo -> StdPhraseAnno anno -> String
outputAsRhythmicMarkup infos infov = 
    ppRender . genOutputAsRhythmicMarkup def infos infov
  where
    def = LY.MarkupOutput { LY.asMarkup = \p -> teeny (braces $ pPrint p) }


printAsRhythmicMarkup :: ScoreInfo -> VoiceInfo -> StdPhrase -> IO ()
printAsRhythmicMarkup infos infov = putStrLn . outputAsRhythmicMarkup infos infov



ppRender :: Doc -> String
ppRender = renderStyle (style {lineLength=500})


--------------------------------------------------------------------------------
-- MIDI

-- Should we have a @genOutputAsMIDI@ function?


writeAsMIDI :: FilePath -> StdPhraseAnno anno -> IO ()
writeAsMIDI path notes = 
    let trk = MIDI.translateToMIDI (MIDI.simpleTrackData 1) (noteTrans notes)
    in MIDI.writeMF1 path [trk]

noteTrans :: StdPhraseAnno anno -> BEAM.Phrase MIDI.MidiPitch RDuration anno
noteTrans = MIDI.translateToMidiPD . translateToBeam


--------------------------------------------------------------------------------
-- Debug...

outputAsTabular :: (Pretty pch, Pretty drn) 
                => ScoreInfo -> Phrase pch drn anno -> String
outputAsTabular _gi ph = ppRender $ mainTabular lo ph
  where
    lo = LeafOutput { pp_pitch     = pPrint
                    , pp_duration  = pPrint
                    , pp_anno      = const empty
                    }

printAsTabular :: (Pretty pch, Pretty drn) 
               => ScoreInfo -> Phrase pch drn anno ->  IO ()
printAsTabular gi = putStrLn . outputAsTabular gi


outputAsLinear :: (Pretty pch, Pretty drn) 
               => ScoreInfo -> Phrase pch drn anno -> String
outputAsLinear _gi ph = ppRender $ mainLinear lo ph
  where
    lo = LeafOutput { pp_pitch     = pPrint
                    , pp_duration  = pPrint
                    , pp_anno      = const empty
                    }

printAsLinear :: (Pretty pch, Pretty drn) 
              => ScoreInfo -> Phrase pch drn anno ->  IO ()
printAsLinear gi = putStrLn . outputAsLinear gi
