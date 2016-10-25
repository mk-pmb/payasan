{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Score.Cadenza.Internal.CadenzaToBeam
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Convert Cadenza syntax to Beam syntax prior to outputting 
-- LilyPond.
--
--------------------------------------------------------------------------------

module Payasan.Score.Cadenza.Internal.CadenzaToBeam
  (
    translateToBeam
  ) where


import Payasan.Score.Cadenza.Internal.Syntax

import qualified Payasan.Base.Internal.BeamSyntax as T


translateToBeam :: Part pch drn anno -> T.Part pch drn anno
translateToBeam                 = partT


partT ::Part pch drn anno -> T.Part pch drn anno
partT (Part info gs)            = T.Part [T.Bar info $ map noteGroupT gs]



noteGroupT :: NoteGroup pch drn anno -> T.NoteGroup pch drn anno
noteGroupT (Atom e)             = T.Atom $ elementT e
noteGroupT (Beamed gs)          = T.Beamed $ map noteGroupT gs
noteGroupT (Tuplet spec es)     = T.Tuplet spec $ map (T.Atom . elementT) es

elementT :: Element pch drn anno -> T.Element pch drn anno
elementT (Note p d a t)         = T.NoteElem (T.Note p d) a t
elementT (Rest d)               = T.Rest d
elementT (Spacer d)             = T.Spacer d
elementT (Skip d)               = T.Skip d
elementT (Punctuation s)        = T.Punctuation s
