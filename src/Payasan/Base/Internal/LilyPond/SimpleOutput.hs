{-# LANGUAGE ScopedTypeVariables        #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.LilyPond.SimpleOutput
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output LilyPond.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.LilyPond.SimpleOutput
  ( 
    LyOutputDef(..)

  , simpleScore
  , simpleVoice

  , scoreHeader
  , renderNotes

  ) where

import Payasan.Base.Internal.LilyPond.Syntax
import Payasan.Base.Internal.LilyPond.Utils
import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.RewriteMonad

import Text.PrettyPrint.HughesPJ        -- package: pretty


type Mon a = Rewrite State a

data State = State { prev_info  :: !LocalContextInfo }

stateZero :: LocalContextInfo -> State
stateZero info = State { prev_info  = info }


setInfo :: LocalContextInfo -> Mon () 
setInfo info = puts (\s -> s { prev_info = info })


deltaMetrical :: LocalContextInfo -> Mon (Maybe Meter)
deltaMetrical (LocalContextInfo { local_meter = m1 }) = 
    fn <$> gets prev_info
  where
    fn prev 
        | local_meter prev == m1 = Nothing
        | otherwise              = Just m1

deltaKey :: LocalContextInfo -> Mon (Maybe Key)
deltaKey (LocalContextInfo { local_key = k1 }) = 
    fn <$> gets prev_info
  where
    fn prev 
        | local_key prev == k1 = Nothing
        | otherwise            = Just k1


--------------------------------------------------------------------------------


data LyOutputDef pch anno = LyOutputDef 
    { printPitch    :: pch -> Doc
    , printAnno     :: anno -> Doc
    }



simpleScore :: LyOutputDef pch anno 
            -> ScoreInfo 
            -> GenLyPhrase pch anno -> Doc
simpleScore def info ph = 
        header 
    $+$ anonBlock (simpleVoice def info ph)
  where
    header          = scoreHeader info


scoreHeader :: ScoreInfo -> Doc
scoreHeader globals = 
    version (global_ly_version globals) $+$ header
  where
    header  = withString (global_title globals) $ \ss ->
                 block (Just $ command "header") (title ss)






--------------------------------------------------------------------------------
-- Notelist


-- @voiceOutput@ specifically for @standard@ pitch output.
--
-- Write alternative functions for other types of output.
-- 
simpleVoice :: LyOutputDef pch anno 
            -> ScoreInfo 
            -> GenLyPhrase pch anno -> Doc
simpleVoice def info ph = modeBlockF (notes_header $+$ notes)
  where
    modeBlockF      = octaveModeBlock (global_ly_octave_mode info)
    local1          = maybe default_local_info id $ firstContextInfo ph
    notes_header    = oPhraseHeader local1
    notes           = renderNotes def ph

octaveModeBlock :: OctaveMode -> Doc -> Doc
octaveModeBlock (AbsPitch)   d  = absolute $+$ d
octaveModeBlock (RelPitch p) d  = block (Just $ relative p) d

oPhraseHeader :: LocalContextInfo -> Doc
oPhraseHeader locals = 
        key   (local_key locals)
    $+$ meter (local_meter locals)


-- | Pitch should be \"context free\" at this point.
--
-- Design note - we only want to write this once.
-- Should allow different pch (standard, drum note, etc.)
-- to be printed. 
--
renderNotes :: forall pch anno. 
               LyOutputDef pch anno -> GenLyPhrase pch anno -> Doc
renderNotes def ph = evalRewrite (oLyPhrase ph) (stateZero first_info)
  where
    first_info :: LocalContextInfo
    first_info  = maybe default_local_info id $ firstContextInfo ph

    pPitch :: pch -> Doc
    pPitch = printPitch def

    pAnno  :: anno -> Doc
    pAnno  = printAnno def

    oLyPhrase :: GenLyPhrase pch anno -> Mon Doc
    oLyPhrase (Phrase [])           = return empty
    oLyPhrase (Phrase (x:xs))       = do { d <- oBar x; step d xs }
      where
        step d []     = return d
        step d (b:bs) = do { d1    <- oBar b
                           ; let ac = d <+> char '|' $+$ d1
                           ; step ac bs 
                           }

    oBar :: GenLyBar pch anno -> Mon Doc
    oBar (Bar locals cs)            = 
          do { dkey    <- deltaKey locals
             ; dmeter  <- deltaMetrical locals
             ; let ans = hsep (map oNoteGroup cs)
             ; setInfo locals
             ; return $ prefixM dmeter $ prefixK dkey $ ans
             }
        where
          prefixK Nothing   = (empty <>)
          prefixK (Just k)  = (key k $+$)
          prefixM Nothing   = (empty <>)
          prefixM (Just m)  = (meter m $+$)

    oNoteGroup :: GenLyNoteGroup pch anno -> Doc
    oNoteGroup (Atom e)             = oElement e
    oNoteGroup (Beamed cs)          = beamForm $ map oNoteGroup cs
    oNoteGroup (Tuplet spec cs)     = tupletSpec spec <+> hsep (map oNoteGroup cs)

    oElement :: GenLyElement pch anno -> Doc
    oElement (NoteElem n a)         = oNote n <> pAnno a
    oElement (Rest d)               = rest d 
    oElement (Skip d)               = skip d 
    oElement (Chord ps d a)         = 
        chordForm (map pPitch ps) <> noteLength d <> pAnno a

    oElement (Graces ns)            = graceForm (map oNote ns)
    oElement (Punctuation s)        = text s


    oNote :: GenLyNote pch -> Doc
    oNote (Note p d)               = pPitch p <> noteLength d