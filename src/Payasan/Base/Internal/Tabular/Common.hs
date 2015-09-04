{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.Tabular.Common
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output to a Humdrum-like form.
--
-- This is intended debugging and checking purposes, so it is
-- specialized to represent Payasan and is not directly 
-- compatible with Humdrum.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.Tabular.Common
  ( 

    LeafOutput(..)

  , std_ly_output
  , lyNoteLength
  , lyPitch

  , std_abc_output
  , abcNoteLength
  , abcPitch

  ) where

import Payasan.Base.Internal.Tabular.Utils

import qualified Payasan.Base.Internal.LilyPond.Syntax as Ly
import qualified Payasan.Base.Internal.ABC.Syntax as ABC

import Text.PrettyPrint.HughesPJClass           -- package: pretty

data LeafOutput pch drn = LeafOutput 
    { pp_pitch          :: pch -> Doc
    , pp_duration       :: drn -> Doc 
    }



std_ly_output :: LeafOutput Ly.Pitch Ly.NoteLength
std_ly_output = LeafOutput { pp_pitch     = lyPitch
                           , pp_duration  = lyNoteLength
                           }

lyNoteLength :: Ly.NoteLength -> Doc
lyNoteLength (Ly.DrnDefault)    = nullDot
lyNoteLength (Ly.DrnExplicit d) = duration d

lyPitch :: Ly.Pitch -> Doc
lyPitch = pPrint


std_abc_output :: LeafOutput ABC.Pitch ABC.NoteLength
std_abc_output = LeafOutput { pp_pitch     = abcPitch
                            , pp_duration  = abcNoteLength
                            }

abcNoteLength :: ABC.NoteLength -> Doc
abcNoteLength (ABC.DNL)         = nullDot
abcNoteLength d                 = pPrint d

abcPitch :: ABC.Pitch -> Doc
abcPitch = pPrint