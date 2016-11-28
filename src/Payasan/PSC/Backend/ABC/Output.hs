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
import Payasan.PSC.Base.Utils

import Payasan.Base.Basis
import Payasan.Base.Scale

import Text.PrettyPrint.HughesPJ hiding ( Mode )       -- package: pretty


type CatOp = Doc -> Doc -> Doc


type Mon a = Rewrite State a

data State = State { prev_info  :: !SectionInfo }

stateZero :: SectionInfo -> State
stateZero info = State { prev_info  = info }



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



oABCPart :: GenABCPart anno -> Mon Doc
oABCPart (Part xs) = do { i <- return 4; step i xs }    -- TODO: line len hardcoded
  where
    step _    []       = return empty
    step cols [s]      = oSection cols (text "|]") s
    step cols (s:ss)   = do { d1 <- oSection cols (char '|') s
                            ; ds <- step cols ss
                            ; return (d1 $+$ ds)
                            }



oSection :: Int -> Doc -> GenABCSection anno -> Mon Doc
oSection cols end (Section _ info cs)  = 
    do { dkey    <- deltaKey info
       ; dmeter  <- deltaMetrical info
       ; let ans = ppSection cols end $ map oBar cs 
       ; setInfo info
       ; return $ prefixM dmeter $ prefixK dkey $ ans
       }
  where
    prefixK Nothing       = (empty <>)
    prefixK (Just k)      = (midtuneField 'K' (key k) <+>)
    prefixM Nothing       = (empty <>)
    prefixM (Just (m,u))  = let doc = ( midtuneField 'M' (meter m) 
                                       <+> midtuneField 'L' (unitNoteLength u))
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

-- Allows different terminator:
--
-- '|' for end of section, "|]" for end of part.
--
ppSection :: Int -> Doc -> [Doc] -> Doc
ppSection cols end bars = 
    ppTable cols (<+>) $ punctuateSepEnd (char '|') end bars
    
    