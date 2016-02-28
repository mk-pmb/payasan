{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE RankNTypes                 #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Elementary.Internal.Traversals
-- Copyright   :  (c) Stephen Tetley 2015-2016
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Generic traversals of Elementary syntax.
--
--------------------------------------------------------------------------------

module Payasan.Base.Elementary.Internal.Traversals
  (
    Cut(..)  

  , accumFull
  , accumFullM
  , accumStop
  , accumStopM

  , accumFullCtx
  , accumFullCtxM
  , accumStopCtx
  , accumStopCtxM

  , accumFullIx
  , accumFullIxM
  , accumStopIx
  , accumStopIxM

  , accumFullCtxIx
  , accumFullCtxIxM
  , accumStopCtxIx
  , accumStopCtxIxM

  , transform
  , transformM
  , transformCtx
  , transformCtxM
  , transformIx
  , transformIxM
  , transformCtxIx
  , transformCtxIxM


  , Mon 

  , ElemPitchAlgo(..)
  , transformP
  , collectP
  , mapPitch
  , ctxMapPitch   -- TEMP ?
  , foldPitch 


  , ElemDurationAlgo(..)
  , transformD
  , collectD
  , mapDuration
  , foldDuration

  , ElemAnnoAlgo(..)
  , transformA
  , collectA
  , mapAnno
  , foldAnno

  , ElemPitchAnnoAlgo(..)
  , transformPA
  , collectPA
  , mapPitchAnno
  , foldPitchAnno

  , censorPunctuation
  , censorAnno
  , changeSkipToRest



  , TraceAlgo(..)
  , trace

  ) where



import Payasan.Base.Elementary.Internal.Syntax

import Payasan.Base.Internal.AnalysisCommon
import Payasan.Base.Internal.AnalysisTrace
import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.RewriteMonad


import Data.Data
import Data.Foldable (foldlM)
import Data.List (mapAccumL)
import Data.Maybe


data Note1 pch drn anno = Note1 pch drn anno
  deriving (Data,Eq,Show,Typeable)



-- Traversals: 
-- query (accum) and transformation (transform)
-- monadic and non-monadic
-- full and cut-off (queries)
-- type changing and type preserving (transforms)
-- context and no-context
-- indexed and non-indexed 

-- cut-off must be a query (extracting sections is a unique operation)
-- type changing and type preserving - only transforms
-- index generally a position, *metrical position* could be useful though


--------------------------------------------------------------------------------
-- Accumulations (queries)

accumFull :: (ac -> Element pch drn anno -> ac) -> ac -> Part pch drn anno -> ac
accumFull f = accumFullIx (\ac _ e -> f ac e)

accumFullM :: Monad m 
           => (ac -> Element pch drn anno -> m ac) -> ac -> Part pch drn anno -> m ac
accumFullM mf = accumFullIxM (\ac _ e -> mf ac e)





data Cut a = Stop a | Go a
  deriving (Eq,Show)


accumStop :: (ac -> Element pch drn anno -> Cut ac) -> ac -> Part pch drn anno -> ac
accumStop f = accumStopIx (\ac _ e -> f ac e)



accumStopM :: (Monad m) => 
              (ac -> Element pch drn anno -> m (Cut ac)) -> ac -> Part pch drn anno -> m ac
accumStopM mf = accumStopIxM (\ac _ e -> mf ac e)


accumFullCtx :: (SectionInfo -> ctx)
             -> (ctx -> ac -> Element pch drn anno -> ac) -> ac -> Part pch drn anno -> ac
accumFullCtx cxf f a0 part = accumFull f1 a0 part
  where
    f1 = f (cxf $ part_header part)



accumFullCtxM :: Monad m =>
                (SectionInfo -> ctx)
             -> (ctx -> ac -> Element pch drn anno -> m ac) 
             -> ac 
             -> Part pch drn anno 
             -> m ac
accumFullCtxM cxf mf a0 part = accumFullM mf1 a0 part
  where
    mf1 = mf (cxf $ part_header part)


accumStopCtx :: (SectionInfo -> ctx)
             -> (ctx -> ac -> Element pch drn anno -> Cut ac) 
             -> ac 
             -> Part pch drn anno 
             -> ac
accumStopCtx cxf f a0 part = accumStop f1 a0 part
  where
    f1 = f (cxf $ part_header part)


accumStopCtxM :: Monad m =>
                (SectionInfo -> ctx)
             -> (ctx -> ac -> Element pch drn anno -> m (Cut ac))
             -> ac 
             -> Part pch drn anno 
             -> m ac
accumStopCtxM cxf mf a0 part = accumStopM mf1 a0 part
  where
    mf1 = mf (cxf $ part_header part)


accumFullIx :: (ac -> Position -> Element pch drn anno -> ac) 
            -> ac 
            -> Part pch drn anno 
            -> ac
accumFullIx f a0 part = step a0 $ viewl $ toLinear part
  where
    step ac Empty             = ac
    step ac ((ix,e) :< rest)  = let ac1 = f ac ix e in step ac1 $ viewl rest


accumFullIxM :: Monad m 
             => (ac -> Position -> Element pch drn anno -> m ac) 
             -> ac 
             -> Part pch drn anno 
             -> m ac
accumFullIxM mf a0 part = step a0 $ viewl $ toLinear part
  where
    step ac Empty             = return ac
    step ac ((ix,e) :< rest)  = do { ac1 <- mf ac ix e
                                   ; step ac1 $ viewl rest }

accumStopIx :: (ac -> Position -> Element pch drn anno -> Cut ac) 
            -> ac 
            -> Part pch drn anno 
            -> ac
accumStopIx f a0 part = step a0 $ viewl $ toLinear part
  where
    step ac Empty             = ac
    step ac ((ix,e) :< rest)  = case f ac ix e of
                                  Stop ac1 -> ac1
                                  Go ac1 -> step ac1 $ viewl rest


accumStopIxM :: (Monad m) => 
                (ac -> Position -> Element pch drn anno -> m (Cut ac)) 
             -> ac 
             -> Part pch drn anno 
             -> m ac
accumStopIxM mf a0 part = step a0 $ viewl $ toLinear part
  where
    step ac Empty             = return ac
    step ac ((ix,e) :< rest)  = mf ac ix e >>= \x -> case x of
                                  Stop ac1 -> return ac1
                                  Go ac1 -> step ac1 $ viewl rest



accumFullCtxIx :: (SectionInfo -> ctx)
               -> (ctx -> ac -> Position -> Element pch drn anno -> ac) 
               -> ac 
               -> Part pch drn anno 
               -> ac
accumFullCtxIx cxf f a0 part = accumFullIx f1 a0 part
  where
    f1 = f (cxf $ part_header part)



accumFullCtxIxM :: Monad m =>
                  (SectionInfo -> ctx)
               -> (ctx -> ac -> Position -> Element pch drn anno -> m ac) 
               -> ac 
               -> Part pch drn anno 
               -> m ac
accumFullCtxIxM cxf mf a0 part = accumFullIxM mf1 a0 part
  where
    mf1 = mf (cxf $ part_header part)


accumStopCtxIx :: (SectionInfo -> ctx)
               -> (ctx -> ac -> Position -> Element pch drn anno -> Cut ac) 
               -> ac 
               -> Part pch drn anno 
               -> ac
accumStopCtxIx cxf f a0 part = accumStopIx f1 a0 part
  where
    f1 = f (cxf $ part_header part)


accumStopCtxIxM :: Monad m =>
                  (SectionInfo -> ctx)
                -> (ctx -> ac -> Position -> Element pch drn anno -> m (Cut ac))
                -> ac 
                -> Part pch drn anno 
                -> m ac
accumStopCtxIxM cxf mf a0 part = accumStopIxM mf1 a0 part
  where
    mf1 = mf (cxf $ part_header part)



--------------------------------------------------------------------------------
-- Transformations


transform :: (Element p1 d1 a1 -> Element p2 d2 a2) 
          -> Part p1 d1 a1 
          -> Part p2 d2 a2
transform f = transformIx (\_ e -> f e)


transformM :: Monad m =>
             (Element p1 d1 a1 -> m (Element p2 d2 a2))
          -> Part p1 d1 a1  
          -> m (Part p2 d2 a2)
transformM mf = transformIxM (\_ e -> mf e)



transformCtx :: (SectionInfo -> ctx)
             -> (ctx -> Element p1 d1 a1 -> Element p2 d2 a2) 
             -> Part p1 d1 a1 
             -> Part p2 d2 a2
transformCtx cxf f part = transform f1 part 
  where
    f1 = f (cxf $ part_header part)



transformCtxM :: Monad m 
              => (SectionInfo -> ctx)
              -> (ctx -> Element p1 d1 a1 -> m (Element p2 d2 a2))
              -> Part p1 d1 a1 
              -> m (Part p2 d2 a2)
transformCtxM cxf mf part = transformM f1 part 
  where
    f1 = mf (cxf $ part_header part)


transformIx :: forall p1 d1 a1 p2 d2 a2. 
               (Position -> Element p1 d1 a1 -> Element p2 d2 a2) 
            -> Part p1 d1 a1 
            -> Part p2 d2 a2
transformIx f (Part info bs0) = Part info $ snd $ bars start_position bs0
  where
   bars :: Position -> [Bar p1 d1 a1] -> (Position, [Bar p2 d2 a2])
   bars = mapAccumL (\ix b -> let (_,b2) = bar1 ix b in (incPositionBar 1 ix,b2)) 

   bar1 :: Position -> Bar p1 d1 a1 -> (Position, Bar p2 d2 a2)
   bar1 ix (Bar cs) = fmap Bar $ mapAccumL ngroup1 ix cs


   ngroup1 :: Position -> NoteGroup p1 d1 a1 -> (Position, NoteGroup p2 d2 a2)
   ngroup1 ix (Atom e)         = let (ix1,e1) = elem1 ix e in (ix1,Atom e1)
   ngroup1 ix (Tuplet spec es) = let (ix1,es1) = mapAccumL elem1 ix es 
                                 in (ix1, Tuplet spec es1)

   elem1 :: Position -> Element p1 d1 a1 -> (Position, Element p2 d2 a2)
   elem1 ix e = let e1 = f ix e in (incPositionIndex 1 ix, e1) 




mapAccumLM :: Monad m => (ac -> a -> m (ac, b)) -> ac -> [a] -> m (ac, [b])
mapAccumLM _  s []      =  return (s, [])
mapAccumLM mf s (x:xs)  =  do { (s1,y) <- mf s x
                              ; (s2,ys) <- mapAccumLM mf s1 xs
                              ; return (s2, y:ys) }


transformIxM :: forall p1 d1 a1 p2 d2 a2 m. 
                Monad m =>
               (Position -> Element p1 d1 a1 -> m (Element p2 d2 a2))
            -> Part p1 d1 a1 
            -> m (Part p2 d2 a2)
transformIxM mf (Part info bs0) = 
    do { bs1 <- fmap snd $ bars start_position bs0
       ; return $ Part info bs1 }
  where
   bars :: Position -> [Bar p1 d1 a1] -> m (Position, [Bar p2 d2 a2])
   bars = mapAccumLM (\ix b -> do { (_,b2) <- bar1 ix b
                                  ; return (incPositionBar 1 ix, b2)} )

   bar1 :: Position -> Bar p1 d1 a1 -> m (Position, Bar p2 d2 a2)
   bar1 ix (Bar cs) = do { (ix1,cs1) <- mapAccumLM ngroup1 ix cs
                         ; return (ix1, Bar cs1) }


   ngroup1 :: Position -> NoteGroup p1 d1 a1 -> m (Position, NoteGroup p2 d2 a2)
   ngroup1 ix (Atom e)         = do { (ix1,e1) <- elem1 ix e 
                                    ; return (ix1,Atom e1) }

   ngroup1 ix (Tuplet spec es) = do { (ix1,es1) <- mapAccumLM elem1 ix es 
                                    ; return (ix1, Tuplet spec es1) }

   elem1 :: Position -> Element p1 d1 a1 -> m (Position, Element p2 d2 a2)
   elem1 ix e = do { e1 <- mf ix e 
                   ; return (incPositionIndex 1 ix, e1) }
                   


transformCtxIx :: (SectionInfo -> ctx)
               -> (ctx -> Position -> Element p1 d1 a1 -> Element p2 d2 a2) 
               -> Part p1 d1 a1 
               -> Part p2 d2 a2
transformCtxIx cxf f part = transformIx f1 part 
  where
    f1 = f (cxf $ part_header part)

transformCtxIxM :: Monad m 
                => (SectionInfo -> ctx)
               -> (ctx -> Position -> Element p1 d1 a1 -> m (Element p2 d2 a2))
               -> Part p1 d1 a1 
               -> m (Part p2 d2 a2)
transformCtxIxM cxf mf part = transformIxM f1 part 
  where
    f1 = mf (cxf $ part_header part)


--------------------------------------------------------------------------------
-- Trafos below /feel/ old...

type Mon st a = Rewrite st a



-- | Do not expose this as it is too general / complex.
--
genCollect :: forall st pch drn anno ac.
              (ac -> Element pch drn anno -> Mon st ac) 
           -> ac 
           -> st
           -> Part pch drn anno 
           -> ac
genCollect mf a0 st ph = evalRewrite (partC a0 ph) st
  where
    partC :: ac -> Part pch drn anno -> Mon st ac
    partC ac (Part info bs)     = local info (foldlM barC ac bs)

    barC :: ac -> Bar pch drn anno -> Mon st ac
    barC ac (Bar cs)            = foldlM noteGroupC ac cs

    noteGroupC :: ac -> NoteGroup pch drn anno -> Mon st ac
    noteGroupC ac (Atom e)      = mf ac e
    noteGroupC ac (Tuplet _ cs) = foldlM mf ac cs


-- | Do not expose this as it is too general / complex.
--
genTransform :: forall st p1 p2 d1 d2 a1 a2. 
                (Element p1 d1 a1 -> Mon st (Element p2 d2 a2))
             -> st
             -> Part p1 d1 a1
             -> Part p2 d2 a2
genTransform elemT st0 ph = 
    evalRewrite (partT ph) st0
  where

    partT :: Part p1 d1 a1 -> Mon st (Part p2 d2 a2) 
    partT (Part info bs)        = local info (Part info <$> mapM barT bs)

    barT :: Bar p1 d1 a1 -> Mon st (Bar p2 d2 a2)
    barT (Bar cs)               = Bar <$> mapM noteGroupT cs

    noteGroupT :: NoteGroup p1 d1 a1 -> Mon st (NoteGroup p2 d2 a2)
    noteGroupT (Atom e)         = Atom <$> elemT e
    noteGroupT (Tuplet spec es) = Tuplet spec <$> mapM elemT es


--------------------------------------------------------------------------------
--

--
-- Design note - this leaks /shape/, possible to change a rest 
-- to a note or vice-versa.
-- 
-- However, this functionality is for /library writers/ not
-- /top level users/ where it seems that acknowledging the 
-- note-rest distinction is useful.
-- 
-- Also it allows us to use element for Maybe when calculating 
-- contours.
--


data ElemPitchAlgo st pch1 pch2 = ElemPitchAlgo 
    { initial_stateP  :: st
    , element_trafoP  :: forall drn anno. 
                         Element pch1 drn anno -> Mon st (Element pch2 drn anno)
    }


transformP :: forall st p1 p2 drn anno. 
              ElemPitchAlgo st p1 p2 
           -> Part p1 drn anno 
           -> Part p2 drn anno
transformP (ElemPitchAlgo { initial_stateP = st0 
                          , element_trafoP = elemT }) = genTransform elemT st0


-- | This is a seems less generally useful than @transformP@ 
-- so we don\'t expose an /algo/.
-- 
collectP :: forall st pch drn anno ac.
            (ac -> pch -> Mon st ac) 
         -> ac 
         -> st
         -> Part pch drn anno 
         -> ac
collectP mf = genCollect elementC
  where
    elementC :: ac -> Element pch drn anno -> Mon st ac
    elementC ac (Note p _ _ _)      = mf ac p
    elementC ac (Rest {})           = pure $ ac
    elementC ac (Spacer {})         = pure $ ac
    elementC ac (Skip {})           = pure $ ac
    elementC ac (Punctuation {})    = pure $ ac



--------------------------------------------------------------------------------
-- Transformation

mapPitch :: (pch1 -> pch2) -> Part pch1 drn anno -> Part pch2 drn anno
mapPitch fn = ctxMapPitch (\_ p -> fn p)


ctxMapPitch :: (Key -> pch1 -> pch2) 
            -> Part pch1 drn anno 
            -> Part pch2 drn anno
ctxMapPitch fn = transformP algo 
  where
    algo  = ElemPitchAlgo { initial_stateP    = ()
                          , element_trafoP    = stepE }

    stepE (Note p d a t)    = (\ks -> Note (fn ks p) d a t) <$> asks section_key
    stepE (Rest d)          = pure $ Rest d
    stepE (Spacer d)        = pure $ Spacer d
    stepE (Skip d)          = pure $ Skip d
    stepE (Punctuation s)   = pure $ Punctuation s


foldPitch :: (ac -> pch -> ac) -> ac -> Part pch drn anno -> ac
foldPitch fn a0 ph = collectP step a0 () ph
  where
    step ac p   = pure $ fn ac p

--------------------------------------------------------------------------------
-- Duration

data ElemDurationAlgo st drn1 drn2 = ElemDurationAlgo 
    { initial_stateD :: st
    , element_trafoD :: forall pch anno. 
                        Element pch drn1 anno -> Mon st (Element pch drn2 anno)
    }


transformD :: forall st pch d1 d2 anno.
              ElemDurationAlgo st d1 d2 
           -> Part pch d1 anno 
           -> Part pch d2 anno
transformD (ElemDurationAlgo { initial_stateD = st0 
                             , element_trafoD = elemT }) = genTransform elemT st0


-- | This is a seems less generally useful than @transformD@ 
-- so we don\'t expose an /algo/.
-- 
collectD :: forall st pch drn anno ac.
            (ac -> drn -> Mon st ac) 
         -> ac 
         -> st
         -> Part pch drn anno 
         -> ac
collectD mf = genCollect elementC
  where
    elementC :: ac -> Element pch drn anno -> Mon st ac
    elementC ac (Note _ d _ _)      = mf ac d
    elementC ac (Rest {})           = pure $ ac
    elementC ac (Spacer {})         = pure $ ac
    elementC ac (Skip {})           = pure $ ac
    elementC ac (Punctuation {})    = pure $ ac

--------------------------------------------------------------------------------
-- Transformation

-- Note - increasing or decreasing duration would imply 
-- recalculating bar lines.

mapDuration :: (drn1 -> drn2) -> Part pch drn1 anno -> Part pch drn2 anno
mapDuration fn = transformD algo 
  where
    algo  = ElemDurationAlgo { initial_stateD   = ()
                             , element_trafoD   = stepE }

    stepE (Note p d a t)        = pure $ Note p (fn d) a t
    stepE (Rest d)              = pure $ Rest (fn d)
    stepE (Spacer d)            = pure $ Spacer (fn d)
    stepE (Skip d)              = pure $ Skip (fn d)
    stepE (Punctuation s)       = pure $ Punctuation s


foldDuration :: (ac -> drn -> ac) -> ac -> Part pch drn anno -> ac
foldDuration fn a0 ph = collectD step a0 () ph
  where
    step ac d   = pure $ fn ac d

--------------------------------------------------------------------------------
-- Annotation


data ElemAnnoAlgo st anno1 anno2 = ElemAnnoAlgo 
    { initial_stateA  :: st
    , element_trafoA  :: forall pch drn. 
                         Element pch drn anno1 -> Mon st (Element pch drn anno2)
    }


transformA :: forall st pch drn a1 a2.
              ElemAnnoAlgo st a1 a2
           -> Part pch drn a1 
           -> Part pch drn a2
transformA (ElemAnnoAlgo { initial_stateA = st0 
                         , element_trafoA = elemT }) = genTransform elemT st0


collectA :: forall st pch drn anno ac.
            (ac -> anno -> Mon st ac) 
         -> ac 
         -> st
         -> Part pch drn anno 
         -> ac
collectA mf = genCollect elementC
  where
    elementC :: ac -> Element pch drn anno -> Mon st ac
    elementC ac (Note _ _ a _)      = mf ac a
    elementC ac (Rest {})           = pure $ ac
    elementC ac (Spacer {})         = pure $ ac
    elementC ac (Skip {})           = pure $ ac
    elementC ac (Punctuation {})    = pure $ ac


--------------------------------------------------------------------------------
-- Transformation


mapAnno :: (anno1 -> anno2) -> Part pch drn anno1 -> Part pch drn anno2
mapAnno fn = transformA algo 
  where
    algo  = ElemAnnoAlgo { initial_stateA   = ()
                         , element_trafoA   = stepE }

    stepE (Note p d a t)        = pure $ Note p d (fn a) t
    stepE (Rest d)              = pure $ Rest d
    stepE (Spacer d)            = pure $ Spacer d
    stepE (Skip d)              = pure $ Skip d
    stepE (Punctuation s)       = pure $ Punctuation s


foldAnno :: (ac -> anno -> ac) -> ac -> Part pch drn anno -> ac
foldAnno fn a0 ph = collectA step a0 () ph
  where
    step ac a   = pure $ fn ac a

--------------------------------------------------------------------------------
-- Pitch and Annotation

data ElemPitchAnnoAlgo st pch1 anno1 pch2 anno2 = ElemPitchAnnoAlgo 
    { initial_statePA :: st
    , element_trafoPA :: 
             forall drn. 
             Element pch1 drn anno1 -> Mon st (Element pch2 drn anno2)
    }


transformPA :: forall st p1 p2 drn a1 a2.
               ElemPitchAnnoAlgo st p1 a1 p2 a2
            -> Part p1 drn a1 
            -> Part p2 drn a2
transformPA (ElemPitchAnnoAlgo { initial_statePA = st0 
                               , element_trafoPA = elemT }) = 
    genTransform elemT st0


collectPA :: forall st pch drn anno ac.
             (ac -> pch -> anno -> Mon st ac) 
          -> ac 
          -> st
          -> Part pch drn anno 
          -> ac
collectPA mf = genCollect elementC
  where
    elementC :: ac -> Element pch drn anno -> Mon st ac
    elementC ac (Note p _ a _)      = mf ac p a
    elementC ac (Rest {})           = pure $ ac
    elementC ac (Spacer {})         = pure $ ac
    elementC ac (Skip {})           = pure $ ac
    elementC ac (Punctuation {})    = pure $ ac



--------------------------------------------------------------------------------
-- Pitch Anno Transformation


mapPitchAnno :: (p1 -> a1 -> (p2,a2)) -> Part p1 drn a1 -> Part p2 drn a2
mapPitchAnno fn = transformPA algo 
  where
    algo  = ElemPitchAnnoAlgo { initial_statePA   = ()
                              , element_trafoPA   = stepE }

    stepE (Note p d a t)    = let (p1,a1) = fn p a in pure $ Note p1 d a1 t
    stepE (Rest d)          = pure $ Rest d
    stepE (Spacer d)        = pure $ Spacer d
    stepE (Skip d)          = pure $ Skip d
    stepE (Punctuation s)   = pure $ Punctuation s

foldPitchAnno :: (ac -> pch -> anno -> ac) -> ac -> Part pch drn anno -> ac
foldPitchAnno fn a0 ph = collectPA step a0 () ph
  where
    step ac p a   = pure $ fn ac p a


--------------------------------------------------------------------------------
-- Punctuation

censorPunctuation :: Part pch drn anno -> Part pch drn anno
censorPunctuation (Part info bs) = Part info (map bar1 bs)
  where
    bar1 (Bar cs)               = Bar $ catMaybes $ map noteGroup1 cs

    noteGroup1 (Atom e)         = censor e >>= (return . Atom)
    noteGroup1 (Tuplet spec es) = let xs = catMaybes $ map censor es
                                  in if null xs then Nothing 
                                                else Just $ Tuplet spec xs


    censor (Punctuation {})     = Nothing
    censor e                    = Just e


--------------------------------------------------------------------------------
-- Markup

censorAnno :: Part pch drn anno -> Part pch drn ()
censorAnno (Part info bs) = Part info (map bar1 bs)
  where
    bar1 (Bar cs)               = Bar $ map noteGroup1 cs

    noteGroup1 (Atom e)         = Atom $ changeNote e
    noteGroup1 (Tuplet spec es) = Tuplet spec $ map changeNote es

    changeNote (Note p d _ t)   = Note p d () t
    changeNote (Rest d)         = Rest d
    changeNote (Spacer d)       = Spacer d
    changeNote (Skip d)         = Skip d
    changeNote (Punctuation s)  = Punctuation s


--------------------------------------------------------------------------------
-- Skip to rest

changeSkipToRest :: Part pch drn anno -> Part pch drn anno
changeSkipToRest (Part info bs) = Part info (map bar1 bs)
  where
    bar1 (Bar cs)               = Bar $ map noteGroup1 cs

    noteGroup1 (Atom e)         = Atom $ changeSkip e
    noteGroup1 (Tuplet spec es) = Tuplet spec $ map changeSkip es

    changeSkip (Skip d)         = Rest d
    changeSkip e                = e



--------------------------------------------------------------------------------
-- Traces

data TraceAlgo st pch drn anno e = TraceAlgo 
    { initial_trace_state :: st
    , element_trace_trafo :: Element pch drn anno -> Mon st (TraceElement e)
    }


trace :: forall st pch drn anno e. 
         TraceAlgo st pch drn anno e
      -> Part pch drn anno
      -> TracePart e
trace (TraceAlgo st0 elemT) ph = evalRewrite (partT ph) st0
  where
    partT :: Part pch drn anno -> Mon st (TracePart e) 
    partT (Part _ bs)           = TracePart <$> mapM barT bs

    barT :: Bar pch drn anno -> Mon st (TraceBar e)
    barT (Bar cs)               = (TraceBar . concat) <$> mapM noteGroupT cs

    noteGroupT :: NoteGroup pch drn anno -> Mon st [TraceElement e]
    noteGroupT (Atom e)         = (\a -> [a]) <$> elemT e
    noteGroupT (Tuplet _ es)    = mapM elemT es


