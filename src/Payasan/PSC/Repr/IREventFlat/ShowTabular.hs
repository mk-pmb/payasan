{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.IREventFlat.ShowTabular
-- Copyright   :  (c) Stephen Tetley 2016-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output IREventFlat syntax to a Humdrum-like event list form.
--
-- This is intended debugging and checking purposes, so it is
-- specialized to represent Payasan and is not directly 
-- compatible with Humdrum.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.IREventFlat.ShowTabular
  ( 

    showTabularIREventFlat
    
  ) where

import Payasan.PSC.Repr.IREventFlat.Syntax

import Payasan.PSC.Base.ShowCommon
import Payasan.PSC.Base.ShowTabularUtils

import Text.PrettyPrint.HughesPJClass                -- package: pretty


showTabularIREventFlat :: LeafOutputEvent onset pch drn anno 
                       -> Part onset drn anno -> Doc
showTabularIREventFlat def ph = concatBars 2 $ oPart def ph


oPart :: LeafOutputEvent onset pch drn anno -> Part onset drn anno -> [Doc]
oPart def (Part xs)             = concat $ map (oSection def) xs

oSection :: LeafOutputEvent onset pch drn anno -> Section onset drn anno -> [Doc]
oSection def (Section { section_events = es })  = map (oEvent def) es


oEvent :: LeafOutputEvent onset pch drn anno -> Event onset drn anno -> Doc
oEvent _def (Event {})    = error "TODO oEvent"
    -- pp_onset def ot <++> (pp_event def) pch d a



