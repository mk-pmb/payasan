{-# LANGUAGE DeriveDataTypeable         #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.Csound.Syntax
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Symbolic notelist segmented into bars, with notes, rests, 
-- chords, grace notes and triplets.
--
-- Concrete syntax following Csound notelists.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.Csound.Syntax
  ( 

    CsoundNoteStream

  , CpsPitch(..)
  , Seconds             -- re-export

  , middle_c

  , toCpsPitch

  ) where

import Payasan.Base.Internal.Base
import qualified Payasan.Base.Internal.BeamSyntax as BEAM

import Payasan.Base.Pitch hiding ( middle_c )

import Text.PrettyPrint.HughesPJClass           -- package: pretty

import Data.Data
import Data.Fixed

--------------------------------------------------------------------------------
-- Syntax


type CsoundNoteStream anno = [BEAM.Element CpsPitch Seconds anno]




-- Use CpsPch - we can always print it as Hz if prefered.
-- 
data CpsPitch = CpsPitch Milli
  deriving (Data,Eq,Ord,Show,Typeable)





middle_c :: CpsPitch
middle_c = CpsPitch 8.000



toCpsPitch :: Pitch -> CpsPitch
toCpsPitch (Pitch (PitchName l a) ove) = CpsPitch $ o + frac
  where
    o    = fromIntegral $ 4 + ove
    semis = fromPitchLetter l + fromAlteration a
    frac = (realToFrac semis) / 100



--------------------------------------------------------------------------------
-- Pretty instances are for debugging.

instance Pretty CpsPitch where 
  pPrint (CpsPitch a)   = text $ show a



