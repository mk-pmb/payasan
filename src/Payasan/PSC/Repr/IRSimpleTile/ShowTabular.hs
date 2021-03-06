{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.IRSimpleTile.ShowTabular
-- Copyright   :  (c) Stephen Tetley 2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output IRSimpleTile syntax to a Humdrum-like event list form.
--
-- This is intended debugging and checking purposes, so it is
-- specialized to represent Payasan and is not directly 
-- compatible with Humdrum.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.IRSimpleTile.ShowTabular
  ( 

    showTabularIRSimpleTile
    
  ) where

import Payasan.PSC.Repr.IRSimpleTile.Syntax

import Payasan.PSC.Base.ShowCommon
import Payasan.PSC.Base.ShowTabularUtils

import Payasan.Base.Basis

import Text.PrettyPrint.HughesPJClass                -- package: pretty


showTabularIRSimpleTile :: LeafOutputNote pch Seconds anno  -> Part pch anno -> Doc
showTabularIRSimpleTile ppl ph = concatBars 2 $ oPart ppl ph

-- TODO - we can generate better output indicating section 
-- delimiting etc.
--
oPart :: LeafOutputNote pch Seconds anno -> Part pch anno -> [Doc]
oPart ppl (Part xs)             = map (oSection ppl) xs

oSection :: LeafOutputNote pch Seconds anno -> Section pch anno -> Doc
oSection ppl (Section { section_bars = xs }) = vcat $ map (oBar ppl) xs

oBar :: LeafOutputNote pch Seconds anno  -> Bar pch anno -> Doc
oBar ppl (Bar { bar_elems = es } )           = vcat $ map (oElement ppl) es



oElement :: LeafOutputNote pch Seconds anno  -> Element pch anno -> Doc
oElement ppl elt = case elt of
    Note d p _          -> oNote ppl p d
    Rest d              -> rest <++> ppD d 
    Chord d ps _        -> oPitches ppl ps <+> ppD d 
    Graces xs           -> vcat $ map (\(d,p) -> oNote ppl p d) xs
    TiedCont d          -> char 'K' <++> ppD d 
  where
    ppD = pp_duration ppl


oNote :: LeafOutputNote pch Seconds anno -> pch -> Seconds -> Doc
oNote ppl p d           = ppP p <++> ppD d
  where
    ppP = pp_pitch ppl
    ppD = pp_duration ppl


oPitches :: LeafOutputNote pch Seconds anno -> [pch] -> Doc
oPitches ppl ps = hcat $ punctuate (char ':') $ map ppP ps
  where
    ppP = pp_pitch ppl
