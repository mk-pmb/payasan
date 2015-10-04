{-# LANGUAGE DeriveDataTypeable         #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.LilyPond.Lyricmode.Internal.Base
-- Copyright   :  (c Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Lyricmode for LilyPond.
--
--------------------------------------------------------------------------------

module Payasan.LilyPond.Lyricmode.Internal.Base
  ( 
   
    StdLyricPhrase
  , LyLyricPhrase
  , LyLyricBar
  , LyLyricNoteGroup
  , LyLyricElement

  , Syllable(..)

  , inTrans

  ) where

import Payasan.Base.Monophonic.Internal.LilyPondInTrans
import qualified Payasan.Base.Monophonic.Internal.Syntax as MONO

import Payasan.Base.Internal.CommonSyntax
import Payasan.Base.Internal.LilyPond.Syntax (LyNoteLength)

import Payasan.Base.Duration

import Text.PrettyPrint.HughesPJClass           -- package: pretty

import Data.Data


type StdLyricPhrase     = MONO.Phrase Syllable Duration ()

type LyLyricPhrase      = MONO.Phrase     Syllable LyNoteLength ()
type LyLyricBar         = MONO.Bar        Syllable LyNoteLength ()
type LyLyricNoteGroup   = MONO.NoteGroup  Syllable LyNoteLength ()
type LyLyricElement     = MONO.Element    Syllable LyNoteLength ()


data Syllable = Syllable String
  deriving (Data,Eq,Ord,Show,Typeable)



--          | ExtenderLine            -- Double underscore
--          | HyphenLine              -- Double hyphen 


--
-- What is an extender? 
-- It cannot be an annotation as it punctuates the note list 
-- rather than annotates a word.
--
-- It has no duration - this makes is somewhat antithetical to 
-- representing it as a pitch for a Note. We don't want to 
-- confuse the LilyPond relative duration transformation or
-- confuse the output printing.
--
-- For the time being we represent it just as a String, while
-- this is not great for pattern matching etc. it prevents 
-- adding another type parameter to the syntax.



instance Pretty Syllable where
  pPrint (Syllable s)   = text s


inTrans :: GlobalRenderInfo 
        -> LyLyricPhrase
        -> StdLyricPhrase
inTrans _info = trafoDuration

