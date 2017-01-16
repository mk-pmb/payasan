{-# LANGUAGE RankNTypes                 #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Csound.Compile
-- Copyright   :  (c) Stephen Tetley 2016-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Compiler for Csound.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Csound.Compile
  ( 
    
    CompilerDef(..)       
  , emptyDef

  , Compiler(..)
  , makeCompiler

  ) where


import Payasan.PSC.Csound.Base
import Payasan.PSC.Csound.Output

import Payasan.PSC.Repr.External.OutTransSeconds
import Payasan.PSC.Repr.External.Syntax
import Payasan.PSC.Repr.IRSimpleTile.FromExternal
import Payasan.PSC.Repr.IREventBar.FromIRSimpleTile
import Payasan.PSC.Repr.IREventFlat.FromIREventBar



import Payasan.PSC.Base.CompilerMonad
import Payasan.PSC.Base.SyntaxCommon
import Payasan.PSC.Base.Utils

import Payasan.Base.Basis
import Payasan.Base.Pitch

import Text.PrettyPrint.HughesPJ                -- package: pretty


import qualified Data.Text              as TEXT
import qualified Data.Text.IO           as TEXT


import Control.Monad.IO.Class
import System.FilePath



data CompilerDef pch anno attrs = CompilerDef
    { pathto_working_dir        :: !FilePath
    , outfile_name              :: !String
    , pathto_csd_template       :: !FilePath
    , template_anchor           :: !String
    , make_event_attrs          :: pch -> anno -> attrs
    , make_grace_attrs          :: pch -> attrs
    , make_istmt                :: Seconds -> Seconds -> attrs -> Doc    
    }
  
emptyDef :: CompilerDef pch anno attrs
emptyDef = CompilerDef
    { pathto_working_dir        = ""
    , outfile_name              = "cs_output.csd"
    , pathto_csd_template       = "./demo/template.csd"
    , template_anchor           = "[|notelist|]"
    }    
    
-- TODO - should provide a method just to compile Part to a doc
-- then this will allow reuse for multi-notelist models 
-- (e.g. polyrhythms)

data Compiler anno = Compiler
   { compile :: StdPart1 anno -> IO ()
   
   }

makeCompiler :: CompilerDef Pitch anno attrs -> Compiler anno
makeCompiler env = 
    Compiler { compile = \part -> prompt (compile1 env part)  >> return ()
             }

type CsdCompile a = CM a



compile1 :: CompilerDef Pitch anno attrs -> StdPart1 anno -> CsdCompile ()
compile1 def part = do 
    { events <- compilePartToEventList1 def part
    ; csd <- assembleOutput1 def events
    ; writeCsdFile1 def csd
    }


-- MakeEventDef pch anno evt 
compilePartToEventList1 :: CompilerDef Pitch anno attrs 
                        -> StdPart1 anno 
                        -> CsdCompile CsdEventListDoc
compilePartToEventList1 def p = 
    let def_bar  = GenEventAttrs { genAttrsFromEvent = make_event_attrs def
                                 , genAttrsFromGrace = make_grace_attrs def }          
        def_flat = GenCsdOutput { genIStmt = make_istmt def }
        irsimple = fromExternal $ transDurationToSeconds p
        irflat   = fromIREventBar def_bar $ fromIRSimpleTile irsimple
    in return $ makeCsdEventListDoc def_flat irflat


-- This is monadic...
assembleOutput1 :: CompilerDef Pitch anno attrs -> CsdEventListDoc -> CsdCompile TEXT.Text
assembleOutput1 def sco = 
    let scotext = TEXT.pack $ ppRender $ extractDoc sco
    in do { xcsd <- readFileCM (pathto_csd_template def)
          ; return $ TEXT.replace (TEXT.pack $ template_anchor def) scotext xcsd
          }

csoundInsertNotes1 :: CompilerDef pch anno attrs -> String -> TEXT.Text -> TEXT.Text
csoundInsertNotes1 def sco = 
    TEXT.replace (TEXT.pack $ template_anchor def) (TEXT.pack sco)


-- | Csd has already been rendered to Text.
--
writeCsdFile1 :: CompilerDef pch anno attrs -> TEXT.Text -> CsdCompile ()
writeCsdFile1 def csd = 
    do { outfile <- workingFileName1 def
       ; liftIO $ TEXT.writeFile outfile csd
       ; return ()
       }

workingFileName1 :: CompilerDef pch anno attrs -> CsdCompile String
workingFileName1 def = 
    do { root <- getWorkingDirectory (Right $ pathto_working_dir def) 
       ; let name = outfile_name def
       ; let outfile = root </> name
       ; return outfile
       }

