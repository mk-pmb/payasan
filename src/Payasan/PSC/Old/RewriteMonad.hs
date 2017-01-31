{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Old.RewriteMonad
-- Copyright   :  (c) Stephen Tetley 2014-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Rewrite Monad - DEPRECATED
-- 
--------------------------------------------------------------------------------

module Payasan.PSC.Old.RewriteMonad
  ( 

    RewriteError
  , Rewrite
  , evalRewrite

  , get
  , gets
  , put
  , modify
  , ask
  , asks
  , local
  , throwError
  
  )  where

import Control.Monad.Except
import Control.Monad.Identity
import Control.Monad.Reader
import Control.Monad.State


--------------------------------------------------------------------------------

type RewriteError = String




-- Rewrite: Reader + State + Except
--
type Rewrite env st = ReaderT env (StateT st (ExceptT RewriteError Identity))


-- TODO - is an Alternative instance useful?
 
evalRewrite :: Rewrite env st a -> env -> st -> Either RewriteError a
evalRewrite ma r s = runIdentity (runExceptT (evalStateT (runReaderT ma r) s))
    
