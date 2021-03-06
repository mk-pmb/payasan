{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.LilyPond.Chordmode.Internal.Output
-- Copyright   :  (c) Stephen Tetley 2015-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output
--
--------------------------------------------------------------------------------

module Payasan.LilyPond.Chordmode.Internal.Output
  ( 
    chordmodeOutput
  ) where

import Payasan.LilyPond.Chordmode.Internal.Base

import Payasan.PSC.LilyPond.SimpleOutput
import Payasan.PSC.LilyPond.Pretty

import qualified Payasan.PSC.Repr.External.Syntax    as EXT

import Payasan.PSC.Base.SyntaxCommon


import Text.PrettyPrint.HughesPJ        -- package: pretty



chordmodeOutput :: String -> String -> OutChordPart -> Doc
chordmodeOutput lyversion title ph = 
        header
    $+$ chordmodeBlock (extractDoc notes)
  where
    header          = scoreHeader lyversion title
    notes           = makeLyNoteList chord_def ph
    chord_def       = LyOutputDef { printPitch = pitch
                                  , printAnno  = oChordSuffix }





chordmodeBlock :: Doc -> Doc
chordmodeBlock doc  = block (Just $ command "chordmode") doc



oChordSuffix :: ChordSuffix -> Doc
oChordSuffix (NamedModifier NO_MOD) = empty
oChordSuffix (NamedModifier m)      = char ':' <> oChordModifier m
oChordSuffix (ChordSteps s)         = char ':' <> oSteps s


oChordModifier :: ChordModifier -> Doc
oChordModifier MAJ13    = text "maj13"
oChordModifier MAJ11    = text "maj11"
oChordModifier MAJ9     = text "maj9"
oChordModifier MAJ7     = text "maj7"
oChordModifier MAJ6     = text "6"
oChordModifier MAJ5     = text "5"
oChordModifier MM7      = text "m7+"              -- Mm7 - needs special case
oChordModifier MIN13    = text "m13"
oChordModifier MIN11    = text "m11"
oChordModifier MIN9     = text "m9"
oChordModifier MIN7     = text "m7"
oChordModifier MIN6     = text "m6"
oChordModifier MIN5     = text "m"
oChordModifier DIM7     = text "dim7"
oChordModifier DIM5     = text "dim"
oChordModifier AUG7     = text "aug7"
oChordModifier AUG5     = text "aug"
oChordModifier SUS4     = text "sus4"
oChordModifier SUS2     = text "sus2"
oChordModifier SUS      = text "sus"
oChordModifier DOM13    = text "13"
oChordModifier DOM11    = text "11"
oChordModifier DOM9     = text "9"
oChordModifier DOM7     = text "7"
oChordModifier NO_MOD   = empty


oSteps :: Steps -> Doc
oSteps s 
    | null $ removals s = fn (additions s)
    | otherwise         = fn (additions s) <> char '^' <> fn (removals s)
  where
    fn [] = empty
    fn xs = hcat $ punctuate (char '.') $ map oStep xs

oStep :: Step -> Doc
oStep (Step i m) = int i <> fn m
  where
    fn NVE = char '-'
    fn PVE = char '+'
    fn _   = empty