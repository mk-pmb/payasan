{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.IREventBeamToIREventFlat
-- Copyright   :  (c) Stephen Tetley 2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Translate IREventBeam to IREventFlat.
-- 
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.IREventBeamToIREventFlat
  ( 
    transIREventBeamToIREventFlat
  ) where

import Payasan.PSC.Repr.IREventBeam.Syntax
import qualified Payasan.PSC.Repr.IREventFlat.Syntax as T


-- NOTE - there is no obligation to fix the type of Onset to
-- Seconds, although it is unlikely to be anything else. 

transIREventBeamToIREventFlat :: Num ot => Part ot evt -> T.Part ot evt
transIREventBeamToIREventFlat = partT


partT :: Num ot => Part ot evt -> T.Part ot evt
partT (Part bs)                     = 
    T.Part { T.part_events = concat $ map barT bs }

barT :: Num ot => Bar ot evt -> [T.Event ot evt]
barT (Bar ot cs)                    = map (eventT ot) cs

eventT :: Num ot => ot -> Event ot evt -> T.Event ot evt
eventT onsetb (Event ot body)   = 
    T.Event { T.event_onset     = onsetb + ot
            , T.event_body      = body
            }