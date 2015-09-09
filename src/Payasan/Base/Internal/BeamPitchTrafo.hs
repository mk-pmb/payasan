{-# LANGUAGE RankNTypes                 #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.BeamPitchTrafo
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Generic traversal of Beam syntax for pitch transformation.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.BeamPitchTrafo
  (
    Mon 
  , BeamPitchAlgo(..)
  , transform
  ) where



import Payasan.Base.Internal.BeamSyntax
import Payasan.Base.Internal.RewriteMonad


type Mon st a = Rewrite st a

data BeamPitchAlgo st pch1 pch2 = BeamPitchAlgo 
    { initial_state     :: st
    , element_trafo     :: forall drn. Element pch1 drn  -> Mon st (Element pch2 drn)
    }


transform :: BeamPitchAlgo st p1 p2 -> Phrase p1 drn -> Phrase p2 drn
transform algo ph = evalRewriteDefault (phraseT algo ph) (initial_state algo)


phraseT :: BeamPitchAlgo st p1 p2 -> Phrase p1 drn -> Mon st (Phrase p2 drn)
phraseT algo (Phrase bs)          = Phrase <$> mapM (barT algo) bs



barT :: BeamPitchAlgo st p1 p2 -> Bar p1 drn -> Mon st (Bar p2 drn)
barT algo (Bar info cs)           = local info $
     Bar info <$> mapM (ctxElementT algo) cs

  
ctxElementT :: BeamPitchAlgo st p1 p2 
            -> CtxElement p1 drn 
            -> Mon st (CtxElement p2 drn)
ctxElementT algo (Atom e)         = let elemT = element_trafo algo
                                    in Atom <$> elemT e
ctxElementT algo (Beamed cs)      = Beamed <$> mapM (ctxElementT algo) cs
ctxElementT algo (Tuplet spec cs) = Tuplet spec <$> mapM (ctxElementT algo) cs

