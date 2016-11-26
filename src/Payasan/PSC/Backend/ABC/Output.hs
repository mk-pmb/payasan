{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Backend.ABC.Output
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Output ABC.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Backend.ABC.Output
  ( 
    abcOutput
  ) where

import Payasan.PSC.Backend.ABC.Utils

import Payasan.PSC.Repr.External.Syntax

import Payasan.PSC.Base.ABCCommon
import Payasan.PSC.Base.RewriteMonad
import Payasan.PSC.Base.SyntaxCommon

import Payasan.Base.Basis
import Payasan.Base.Scale

import Text.PrettyPrint.HughesPJ hiding ( Mode )       -- package: pretty


type CatOp = Doc -> Doc -> Doc

-- Generating output should be stateful so we can insert a 
-- newline every four lines.

type Mon a = Rewrite State a

data State = State { bar_column :: !Int
                   , prev_info  :: !SectionInfo
                   }

stateZero :: SectionInfo -> State
stateZero info = State { bar_column = 0
                       , prev_info  = info }

lineLen :: Mon Int
lineLen = gets bar_column

resetLineLen :: Mon ()
resetLineLen = puts (\s -> s { bar_column = 0 })

incrLineLen :: Mon ()
incrLineLen = puts (\s -> s { bar_column = 1 + bar_column s })


setInfo :: SectionInfo -> Mon () 
setInfo info = puts (\s -> s { prev_info = info })


deltaMetrical :: SectionInfo -> Mon (Maybe (Meter,UnitNoteLength))
deltaMetrical (SectionInfo { section_meter = m1
                           , section_unit_note_len = u1 }) = 
    fn <$> gets prev_info
  where
    fn prev 
        | section_meter prev == m1 && section_unit_note_len prev == u1 = Nothing
        | otherwise        = Just (m1,u1)

deltaKey :: SectionInfo -> Mon (Maybe Key)
deltaKey (SectionInfo { section_key = k1 }) = 
    fn <$> gets prev_info
  where
    fn prev 
        | section_key prev == k1 = Nothing
        | otherwise           = Just k1


--------------------------------------------------------------------------------

-- ABC can handle annotations - it simply ignores them.

type GenABCPart anno            = Part        ABCPitch ABCNoteLength anno
type GenABCSection anno         = Section     ABCPitch ABCNoteLength anno
type GenABCBar anno             = Bar         ABCPitch ABCNoteLength anno
type GenABCNoteGroup anno       = NoteGroup   ABCPitch ABCNoteLength anno
type GenABCElement anno         = Element     ABCPitch ABCNoteLength anno



abcOutput :: ScoreInfo -> StaffInfo -> GenABCPart anno -> Doc
abcOutput infos staff ph = header $+$ body
  where
    first_info  = maybe default_section_info id $ firstSectionInfo ph
    header      = oHeader infos staff first_info
    body        = evalRewrite (oABCPart ph) (stateZero first_info)

-- | Note X field must be first K field should be last -
-- see abcplus manual page 11.
--
oHeader :: ScoreInfo -> StaffInfo -> SectionInfo -> Doc
oHeader infos staff locals = 
        field 'X' (int 1)
    $+$ field 'T' (text   $ score_title infos)
    $+$ field 'M' (meter  $ section_meter locals)
    $+$ field 'L' (unitNoteLength $ section_unit_note_len locals)
    $+$ field 'K' key_clef 
  where
    key_clef = (key $ section_key locals) <+> (clef $ staff_clef staff)

-- TODO
-- We can park some of this complexity in better pretty-print 
-- combinators rather than mix in all the logic here.

oABCPart :: GenABCPart anno -> Mon Doc
oABCPart (Part [])              = return empty
oABCPart (Part (x:xs))          = do { d <- oSection x; step d xs }
  where
    step d []     = return $ d <+> text "|]"
    step d (b:bs) = do { i <- lineLen
                       ; if i > 4 then resetLineLen else incrLineLen
                       ; d1 <- oSection b 
                       ; let ac = if i > 4 then (d <+> char '|' $+$ d1) 
                                           else (d <+> char '|' <+> d1)
                       ; step ac bs
                       }



oSection :: GenABCSection anno -> Mon Doc
oSection (Section _ info cs)              = 
    do { dkey    <- deltaKey info
       ; dmeter  <- deltaMetrical info
       ; let ans = vcat $ map oBar cs           -- TODO wrong we want better control of number of bars per line
       ; setInfo info
       ; return $ prefixM dmeter $ prefixK dkey $ ans
       }
  where
    prefixK Nothing       = (empty <>)
    prefixK (Just k)      = (midtuneField 'K' (key k) <+>)
    prefixM Nothing       = (empty <>)
    prefixM (Just (m,u))  = let doc = ( midtuneField 'M' (meter m) 
                                       <> midtuneField 'L' (unitNoteLength u))
                            in (doc <+>)

oBar :: GenABCBar anno -> Doc
oBar (Bar cs) = oNoteGroupList (<+>) cs

oNoteGroupList :: CatOp -> [GenABCNoteGroup anno] -> Doc
oNoteGroupList op xs            = sepList op $ map (oNoteGroup op) xs

oNoteGroup :: CatOp -> GenABCNoteGroup anno -> Doc
oNoteGroup op (Atom e)          = oElement op e
oNoteGroup _  (Beamed cs)       = oNoteGroupList (<>) cs
oNoteGroup op (Tuplet spec cs)  = tupletSpec spec <> oNoteGroupList op cs


-- | Punctuation is not used by ABC.
--
-- Skip is treated as a spacer.
--
oElement :: CatOp -> GenABCElement anno -> Doc
oElement op (NoteElem n _ t)    = tied op (note n) t
oElement _  (Rest d)            = rest d 
oElement _  (Spacer d)          = spacer d 
oElement _  (Skip d)            = spacer d 
oElement op (Chord ps d _ t)    = tied op (chord ps d) t
oElement _  (Graces xs)         = graceForm $ map note xs
oElement _  (Punctuation {})    = empty


tied :: CatOp -> Doc -> Tie -> Doc
tied _  d NO_TIE = d
tied op d TIE    = d `op` char '-'