{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.LilyPond.Output
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

module Payasan.Base.Internal.LilyPond.Output
  ( 
    lyOutput
  ) where

import Payasan.Base.Internal.LilyPond.Syntax
import Payasan.Base.Internal.LilyPond.Utils
import Payasan.Base.Internal.Utils

import Text.PrettyPrint.HughesPJ        -- package: pretty



-- Do we need the monad? (code originally from ABC output where we did).

type Mon a = Trans () Int a


lyOutput :: LyPhrase -> Doc
lyOutput ph = evalTrans (oLyPhrase ph) () 0



oLyPhrase :: LyPhrase -> Mon Doc
oLyPhrase (LyPhrase [])       = return empty
oLyPhrase (LyPhrase (x:xs))   = step (oBar x) xs
  where
    step d []     = return d
    step d (b:bs) = do { let ac = d <+> char '|' $+$ oBar b
                       ; step ac bs
                       }


oBar :: Bar -> Doc
oBar (Bar _info cs) = hsep (map oCtxElement cs)



oCtxElement :: CtxElement -> Doc
oCtxElement (Atom e)            = oElement e
oCtxElement (Beamed cs)         = beamForm $ map oCtxElement cs
oCtxElement (Tuplet spec cs)    = tupletSpec spec <+> hsep (map oCtxElement cs)

oElement :: Element -> Doc
oElement (NoteElem n)           = note n
oElement (Rest d)               = rest d 
oElement (Chord ps d)           = chord ps d 
oElement (Graces xs)            = graces xs
