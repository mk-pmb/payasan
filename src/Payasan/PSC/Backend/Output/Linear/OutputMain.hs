{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Backend.Output.Linear.OutputMain
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output Main syntax to a linear form.
--
-- This is intended debugging and checking purposes.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Backend.Output.Linear.OutputMain
  ( 

    mainLinear
    
  ) where

import Payasan.PSC.Repr.External.Syntax

import Payasan.PSC.Backend.Output.Common
import Payasan.PSC.Backend.Output.Linear.Utils


import Text.PrettyPrint.HughesPJClass                -- package: pretty


mainLinear :: LeafOutput pch drn anno -> Part pch drn anno -> Doc
mainLinear ppl ph = concatBars $ oPart ppl ph


oPart :: LeafOutput pch drn anno -> Part pch drn anno -> [Doc]
oPart ppl (Part xs)             = map (oBar ppl) xs


oBar :: LeafOutput pch drn anno -> Bar pch drn anno -> Doc
oBar ppl (Bar _info cs)         =  oNoteGroupList ppl cs


oNoteGroupList :: LeafOutput pch drn anno -> [NoteGroup pch drn anno] -> Doc
oNoteGroupList ppl xs = vcat $ map (oNoteGroup ppl) xs


oNoteGroup :: LeafOutput pch drn anno -> NoteGroup pch drn anno -> Doc
oNoteGroup ppl (Atom e)         = oElement ppl e
oNoteGroup ppl (Tuplet _ cs)    = oNoteGroupList ppl cs

oElement :: LeafOutput pch drn anno -> Element pch drn anno -> Doc
oElement ppl elt = case elt of
    NoteElem n _ _      -> oNote ppl n
    Rest d              -> rest <> ppD d 
    Spacer d            -> spacer <> ppD d 
    Skip d              -> skip <> ppD d 
    Chord ps d _ _      -> oPitches ppl ps <+> ppD d 
    Graces xs           -> vcat $ map (oNote ppl) xs
    Punctuation s       -> text s
  where
    ppD = pp_duration ppl

oNote :: LeafOutput pch drn anno -> Note pch drn -> Doc
oNote ppl (Note p d)          = ppP p <> ppD d
  where
    ppP = pp_pitch ppl
    ppD = pp_duration ppl

oPitches :: LeafOutput pch drn anno -> [pch] -> Doc
oPitches ppl ps = hcat $ punctuate (char ':') $ map ppP ps
  where
    ppP = pp_pitch ppl


