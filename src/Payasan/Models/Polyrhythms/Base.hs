{-# LANGUAGE ScopedTypeVariables        #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Models.Polyrhythms.Base
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  Stephen Tetley <stephen.tetley@gmail.com>
-- Stability   :  highly unstable
-- Portability :  to be determined.
--
-- Polyrhythms
--
--------------------------------------------------------------------------------

module Payasan.Models.Polyrhythms.Base
  ( 

    outputAsLilyPond
  , outputTimbalesStyle

  ) where

import Payasan.LilyPond.Percussion.Internal.Base

import qualified Payasan.Base.Internal.LilyPond.OutTrans        as LY
import Payasan.Base.Internal.LilyPond.SimpleOutput
import Payasan.Base.Internal.LilyPond.Syntax
import Payasan.Base.Internal.LilyPond.Utils

import Payasan.Base.Internal.AddBeams
import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.BeamTraversals
import Payasan.Base.Internal.CommonSyntax
import qualified Payasan.Base.Internal.Pipeline                 as MAIN

import Payasan.Base.Duration
import Payasan.Base.Pitch

import Text.PrettyPrint.HughesPJClass           -- package: pretty

-- Print two voices.
--
outputAsLilyPond :: ScoreInfo 
                 -> StaffInfo
                 -> Pitch -> MAIN.StdPhrase 
                 -> Pitch -> MAIN.StdPhrase 
                 -> String
outputAsLilyPond globals staff p1 ph1 p2 ph2 = 
    MAIN.ppRender $ MAIN.genOutputAsLilyPond2 config2 ph1 ph2
  where
    config2         = MAIN.LilyPondPipeline2
                        { MAIN.pipe2_beam_trafo1   = addBeams
                        , MAIN.pipe2_out_trafo1    = LY.translateToOutput_Relative p1
                        , MAIN.pipe2_beam_trafo2   = addBeams
                        , MAIN.pipe2_out_trafo2    = LY.translateToOutput_Relative p2
                        , MAIN.pipe2_output_func   = polyrhythmScore globals staff p1 p2
                        }



outputTimbalesStyle :: ScoreInfo 
                    -> MAIN.StdPhrase 
                    -> MAIN.StdPhrase 
                    -> String
outputTimbalesStyle globals ph1 ph2 =
    MAIN.ppRender $ MAIN.genOutputAsLilyPond2 config2 ph1 ph2
  where
    config2         = MAIN.LilyPondPipeline2
                        { MAIN.pipe2_beam_trafo1   = addBeams
                        , MAIN.pipe2_out_trafo1    = timbalesTrafo Hitimbale
                        , MAIN.pipe2_beam_trafo2   = addBeams
                        , MAIN.pipe2_out_trafo2    = timbalesTrafo Lotimbale
                        , MAIN.pipe2_output_func   = timbalesStyle globals
                        }


timbalesTrafo :: DrumPitch 
              -> Phrase pch Duration a 
              -> Phrase DrumPitch LyNoteLength a
timbalesTrafo pch = 
    transformP (drumnote_algo pch) . LY.translateToOutput_DurationOnly



drumnote_algo :: DrumPitch -> BeamPitchAlgo () pch DrumPitch
drumnote_algo pch = BeamPitchAlgo
    { initial_stateP    = ()
    , element_trafoP    = liftElementTrafo $ elementP pch
    }


elementP :: forall pch drn anno. 
            DrumPitch
         -> Element pch drn anno 
         -> Element DrumPitch drn anno
elementP dpitch elt = case elt of 
    NoteElem e a t      -> NoteElem (noteP e) a t
    Rest d              -> Rest d
    Spacer d            -> Spacer d
    Skip d              -> Skip d
    Chord _ d a t       -> 
        NoteElem (Note dpitch d) a t

    Graces ns           -> Graces $ map noteP ns
    Punctuation s       -> Punctuation s
  where
    noteP :: Note pch drn -> Note DrumPitch drn
    noteP (Note _ drn)         = Note dpitch drn


--------------------------------------------------------------------------------
-- Output


-- Key and time signature form a common prefix...
--
polyrhythmScore :: Anno a1 
                => ScoreInfo 
                -> StaffInfo
                -> Pitch
                -> Pitch
                -> Phrase LyPitch LyNoteLength a1 
                -> Phrase LyPitch LyNoteLength a1
                -> Doc
polyrhythmScore globals staff p1 p2 ph1 ph2 = 
        header $+$ newStaff_ <+> (simultaneous1 (startphrase $+$ upper $+$ lower))
  where
    header      = scoreHeader globals
    locals1     = maybe default_local_info id $ firstContextInfo ph1
    startphrase = oPhraseHeader staff locals1
    upper       = newVoiceDefn "upper" $+$ anonBlock (command "voiceOne" <+> upper1)
    upper1      = polyVoice_Relative def p1 locals1 ph1
    lower       = newVoiceDefn "lower" $+$ anonBlock (command "voiceTwo" <+> lower1)
    lower1      = polyVoice_Relative def p2 locals1 ph2
    def         = LyOutputDef { printPitch = pitch, printAnno = anno }


-- TODO - avoid extra line for unmetered...
--
oPhraseHeader :: StaffInfo -> LocalContextInfo -> Doc
oPhraseHeader staff locals = 
        clef_ (staff_clef staff)
    $+$ key_  (local_key locals)
    $+$ case local_meter locals of Unmetered -> empty
                                   TimeSig t -> time_ t


polyVoice_Relative :: LyOutputDef pch anno 
                   -> Pitch
                   -> LocalContextInfo
                   -> LyPhrase2 pch anno -> Doc
polyVoice_Relative def pch locals ph = 
    block (Just $ relative_ pch) notes
  where
    notes           = lilypondNotes def locals ph



--------------------------------------------------------------------------------
-- Timbales style output


timbalesStyle :: Anno a1 
              => ScoreInfo 
              -> Phrase DrumPitch LyNoteLength a1 
              -> Phrase DrumPitch LyNoteLength a1
              -> Doc
timbalesStyle globals ph1 ph2 = 
        header $+$ upper_def $+$ lower_def $+$ block (Just score_) score
  where
    header      = scoreHeader globals
    locals1     = maybe default_local_info id $ firstContextInfo ph1
    upper_def   = phraseDef "upper" locals1 ph1
    lower_def   = phraseDef "lower" locals1 ph2

    score       =     newDrumStaffWith_ overrides 
                  $+$ simultaneous1 (upper_voice $+$ lower_voice)

    overrides   = vcat $ [ definition "drumStyleTable" $ value "timbales-style"
                         , override_ "StaffSymbol.line-count = #2"
                         , override_ "StaffSymbol.staff-space = #(magstep 3)"
                         ]

    upper_voice = newDrumVoice_ <+> anonBlock (stemUp_ <+> command "upper")
    lower_voice = newDrumVoice_ <+> anonBlock (stemDown_ <+> command "lower")


phraseDef :: Anno anno
          => String -> LocalContextInfo -> LyPhrase2 DrumPitch anno -> Doc
phraseDef name locals ph = 
    definition name $ polyVoice_Drum locals ph


polyVoice_Drum :: Anno anno
               => LocalContextInfo -> LyPhrase2 DrumPitch anno -> Doc
polyVoice_Drum locals ph = 
    block (Just $ drummode_) notes
  where
    notes           = lilypondNotes def locals ph
    def             = LyOutputDef { printPitch = pPrint, printAnno = anno }