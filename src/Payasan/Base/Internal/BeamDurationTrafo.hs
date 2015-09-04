{-# LANGUAGE RankNTypes                 #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.BeamDurationTrafo
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Generic traversal of Beam syntax for duration transformation.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.BeamDurationTrafo
  (
    Mon 
  , BeamDurationAlgo(..)
  , transform
  ) where



import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.Utils


type Mon st a = Trans () st a

data BeamDurationAlgo st drn1 drn2 = BeamDurationAlgo 
    { initial_state     :: st
    , bar_info_action   :: LocalRenderInfo -> Mon st ()
    , element_trafo     :: forall pch. Element pch drn1  -> Mon st (Element pch drn2)
    }


transform :: BeamDurationAlgo st d1 d2 -> Phrase pch d1 -> Phrase pch d2
transform algo ph = evalTrans (phraseT algo ph) () (initial_state algo)


phraseT :: BeamDurationAlgo st d1 d2 -> Phrase pch d1 -> Mon st (Phrase pch d2)
phraseT algo (Phrase bs)          = Phrase <$> mapM (barT algo) bs



barT :: BeamDurationAlgo st d1 d2 -> Bar pch d1 -> Mon st (Bar pch d2)
barT algo (Bar info cs)           = 
    do { barInfo info
       ; cs1 <- mapM (ctxElementT algo) cs
       ; return $ Bar info cs1 
       }
  where
    barInfo = bar_info_action algo


  
ctxElementT :: BeamDurationAlgo st d1 d2 
            -> CtxElement pch d1
            -> Mon st (CtxElement pch d2)
ctxElementT algo (Atom e)         = let elemT = element_trafo algo
                                    in Atom <$> elemT e
ctxElementT algo (Beamed cs)      = Beamed <$> mapM (ctxElementT algo) cs
ctxElementT algo (Tuplet spec cs) = Tuplet spec <$> mapM (ctxElementT algo) cs

