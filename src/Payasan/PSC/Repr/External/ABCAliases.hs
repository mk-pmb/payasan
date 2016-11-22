{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.External.ABCAliases
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Symbolic notelist segmented into bars, with notes, rests, 
-- chords, grace notes and triplets.
--
-- Concrete syntax following ABC.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.External.ABCAliases
  ( 

    ABCPart
  , ABCBar
  , ABCNoteGroup
  , ABCElement
  , ABCNote

  , ABCPart1
  , ABCBar1
  , ABCNoteGroup1
  , ABCElement1



  ) where

import Payasan.PSC.Repr.External.Syntax
import Payasan.PSC.Base.ABCCommon




--------------------------------------------------------------------------------
-- Syntax

-- | ABC is not annotated, though polymorphic anno is used
-- so that /more/ syntax can be printed.

type ABCPart                    = ABCPart1      ()
type ABCBar                     = ABCBar1       ()      
type ABCNoteGroup               = ABCNoteGroup1 ()
type ABCElement                 = ABCElement1   ()
type ABCNote                    = Note          ABCPitch ABCNoteLength


-- Gen- prefix indicates the must general syntax allowed.

type ABCPart1 anno              = Part        ABCPitch ABCNoteLength anno
type ABCBar1 anno               = Bar         ABCPitch ABCNoteLength anno
type ABCNoteGroup1 anno         = NoteGroup   ABCPitch ABCNoteLength anno
type ABCElement1 anno           = Element     ABCPitch ABCNoteLength anno




