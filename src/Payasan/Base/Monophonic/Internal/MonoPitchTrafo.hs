{-# LANGUAGE RankNTypes                 #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Monophonic.Internal.MonoPitchTrafo
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Generic traversal of Mono syntax for pitch transformation.
--
--------------------------------------------------------------------------------

module Payasan.Base.Monophonic.Internal.MonoPitchTrafo
  (
    Mon 
  , MonoPitchAlgo(..)
  , transform
  , mapPch
  , ctxMapPch   -- TEMP ?
  ) where



import Payasan.Base.Monophonic.Internal.Syntax
import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.RewriteMonad


type Mon st a = Rewrite st a

data MonoPitchAlgo st pch1 pch2 = MonoPitchAlgo 
    { initial_state :: st
    , element_trafo :: forall drn anno. 
                       Element pch1 drn anno -> Mon st (Element pch2 drn anno)
    }


transform :: MonoPitchAlgo st p1 p2 
          -> Phrase p1 drn anno 
          -> Phrase p2 drn anno
transform algo ph = evalRewriteDefault (phraseT algo ph) (initial_state algo)


phraseT :: MonoPitchAlgo st p1 p2 
        -> Phrase p1 drn anno 
        -> Mon st (Phrase p2 drn anno) 
phraseT algo (Phrase bs)          = Phrase <$> mapM (barT algo) bs



barT :: MonoPitchAlgo st p1 p2 -> Bar p1 drn anno -> Mon st (Bar p2 drn anno)
barT algo (Bar info cs)           = local info $ 
    Bar info <$> mapM (noteGroupT algo) cs

  
noteGroupT :: MonoPitchAlgo st p1 p2 
           -> NoteGroup p1 drn anno
           -> Mon st (NoteGroup p2 drn anno)
noteGroupT algo (Atom e)          = let elemT = element_trafo algo
                                    in Atom <$> elemT e
noteGroupT algo (Tuplet spec cs)  = Tuplet spec <$> mapM (noteGroupT algo) cs



--------------------------------------------------------------------------------
-- Transformation

mapPch :: (pch1 -> pch2) -> Phrase pch1 drn anno -> Phrase pch2 drn anno
mapPch fn = ctxMapPch (\_ p -> fn p)


ctxMapPch :: (Key -> pch1 -> pch2) 
          -> Phrase pch1 drn anno 
          -> Phrase pch2 drn anno
ctxMapPch fn = transform algo 
  where
    algo  = MonoPitchAlgo { initial_state    = ()
                          , element_trafo    = stepE 
                          }

    stepE (Note p d a)  = (\ks -> Note (fn ks p) d a) <$> asksLocal local_key
    stepE (Rest d)      = pure $ Rest d

