{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Score.Elementary.Internal.Plain
-- Copyright   :  (c) Stephen Tetley 2015-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- /Plain/ constructor syntax, not quasiquoted.
--
--------------------------------------------------------------------------------

module Payasan.Score.Elementary.Internal.Plain
  ( 
    NoteListAtom
  , fromNoteList
  , note
  , rest

  ) where


import Payasan.Score.Elementary.Internal.RecalcBars
import Payasan.Score.Elementary.Internal.Syntax

import Payasan.PSC.Base.SyntaxCommon

import Payasan.Base.Duration
import Payasan.Base.Pitch

type NoteListAtom = NoteGroup Pitch Duration ()

fromNoteList :: String -> SectionInfo -> [NoteListAtom] -> Section Pitch Duration ()
fromNoteList name info xs = recalcBars $ Section name info [Bar xs]

note :: Pitch -> Duration -> NoteListAtom
note p d = Atom $ Note p d () NO_TIE

rest :: Duration -> NoteListAtom
rest d = Atom $ Rest d 