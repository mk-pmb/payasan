{-# LANGUAGE DeriveDataTypeable         #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.External.BeamGrouping
-- Copyright   :  (c) Stephen Tetley 2015-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Beam grouping (notelists are already segmented into bars). 
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.External.BeamGrouping
  (
    addBeams
  , noBeams
  ) where



import Payasan.PSC.Repr.External.Syntax
import Payasan.PSC.Base.SyntaxCommon
import Payasan.Base.Duration


import Data.Ratio



addBeams :: Part pch Duration anno -> Part pch Duration anno
addBeams (Part { part_sections = ss }) = Part $ map beamSection ss

beamSection :: Section pch Duration anno -> Section pch Duration anno
beamSection (Section name info bs) = 
    Section name info $ map (beamBar info) bs

beamBar :: SectionInfo -> Bar pch Duration anno -> Bar pch Duration anno
beamBar info (Bar cs) = 
    let mpat  = section_meter_pattern info
        segs1 = detachExtremities $ singleout $ segment mpat cs
    in Bar $ beamSegments segs1



-- TO DO - this should remove all beam groups...
--
noBeams :: Part pch Duration anno -> Part pch Duration anno
noBeams (Part { part_sections = ss }) = 
    Part { part_sections = map noBeamSection ss }

noBeamSection :: Section pch Duration anno -> Section pch Duration anno
noBeamSection (Section name info bs) = 
    Section name info $ map noBeamBar bs


noBeamBar :: Bar pch Duration anno -> Bar pch Duration anno
noBeamBar (Bar { note_groups = cs }) = 
    Bar { note_groups = makeSingle cs } 
  where
    makeSingle [] = []
    makeSingle (Beamed es   : xs) = makeSingle es ++ makeSingle xs
    makeSingle (Atom e      : xs) = Atom e : makeSingle xs
    makeSingle (Tuplet s es : xs) = Tuplet s (makeSingle es) : makeSingle xs






--------------------------------------------------------------------------------
-- Segment

-- This algo identifies /candidate/ groups for beaming, it does
-- not divide the bar strictly according to the meter pattern.
-- Due to /straddling/ ther may be more candidate groups than 
-- meter pattern divisions.

data InputRest pch drn anno = 
      GoodSplit [NoteGroup pch drn anno]
    | Straddle  RatDuration  (NoteGroup pch drn anno)   [NoteGroup pch drn anno]



segment :: MeterPattern 
        -> [NoteGroup pch Duration anno] 
        -> [[NoteGroup pch Duration anno]]
segment []     xs = runOut xs
segment (d:ds) xs = let (seg1, rest) = segment1 d xs in
    case rest of 
       (GoodSplit ys) -> seg1 : segment ds ys
       (Straddle rightd y ys) -> seg1 : [y] : segment (decrease rightd ds) ys


segment1 :: RatDuration 
         -> [NoteGroup pch Duration anno] 
         -> ([NoteGroup pch Duration anno], InputRest pch Duration anno)
segment1 _   []     = ([], GoodSplit [])
segment1 drn (x:xs) = step [] drn (x,sizeNoteGroup x) xs
  where
    step ac d (a,d1) cs@(b:bs) 
         | d1 <  d       = step (a:ac) (d - d1) (b, sizeNoteGroup b) bs
         | d1 == d      = (reverse (a:ac), GoodSplit cs)
         | otherwise    = (reverse ac,     Straddle (d1 - d) a cs)

    step ac d (a,d1) []        
         | d1 <= d      = (reverse (a:ac), GoodSplit [])
         | otherwise    = (reverse ac,     Straddle (d1 - d) a [])

runOut :: [NoteGroup pch Duration anno] -> [[NoteGroup pch Duration anno]]
runOut = map (\a -> [a])


decrease :: RatDuration -> MeterPattern -> MeterPattern
decrease _ []         = []
decrease r (d:ds)     
    | r <  d          = (d - r) : ds
    | r == d          = ds
    | otherwise       = decrease (r - d) ds

--------------------------------------------------------------------------------
-- Single out long notes (quater notes or longer)


singleout :: [[NoteGroup pch Duration anno]] -> [[NoteGroup pch Duration anno]]
singleout = concatMap singleout1

singleout1 :: [NoteGroup pch Duration anno] -> [[NoteGroup pch Duration anno]]
singleout1 [] = []
singleout1 (x:xs) = step [] x xs
  where
    step ac a []        
        | isSmall a     = [ reverse (a:ac) ]
        | otherwise     = [reverse ac, [a]]

    step ac a (y:ys) 
        | isSmall a     = step (a:ac) y ys
        | otherwise     = (reverse ac) : [a] : step [] y ys


isSmall :: NoteGroup pch Duration anno -> Bool
isSmall a = sizeNoteGroup a < qtrnote_len

qtrnote_len :: RatDuration 
qtrnote_len = (1%4)



--------------------------------------------------------------------------------
-- Detach extremities

--
-- Beam groups should not start or end with rests 
-- (and spacers if we add them).
--

-- | Lists of NoteGroup are so short in Bars that 
-- we dont care about (++).
--

detachExtremities :: [[NoteGroup pch Duration anno]] 
                  -> [[NoteGroup pch Duration anno]]
detachExtremities = concatMap detachBeamed


detachBeamed :: [NoteGroup pch Duration anno] 
             -> [[NoteGroup pch Duration anno]]
detachBeamed xs = 
    let (as,rest)       = frontAndRest xs
        (csr,middler)   = frontAndRest $ reverse rest
    in [as, reverse middler, reverse csr]
  where
    frontAndRest                    = span detachable


-- | If we already have a Tuplet or Beam group at the left or right
-- of the beam group we assume they are well formed
-- 
detachable :: NoteGroup pch drn anno -> Bool
detachable (Atom e) = detachableE e
detachable _        = False

detachableE :: Element pch drn anno -> Bool
detachableE (Rest {})           = True
detachableE (Spacer {})         = True
detachableE (Skip {})           = True
detachableE (Note {})           = False
detachableE (Chord {})          = False
detachableE (Graces {})         = False
detachableE (Punctuation {})    = True



--------------------------------------------------------------------------------
-- Finally beam

-- | Beam segments with 2 or more members.
--
beamSegments :: [[NoteGroup pch Duration anno]] -> [NoteGroup pch Duration anno]
beamSegments []              = []
beamSegments ([]:xss)        = beamSegments xss
beamSegments ([x]:xss)       = x : beamSegments xss
beamSegments (xs:xss)        = Beamed xs : beamSegments xss
