{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.Base.Internal.Output.Tabular.Utils
-- Copyright   :  (c) Stephen Tetley 2015
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Helpers to print in Humdrum-like format.
--
--------------------------------------------------------------------------------

module Payasan.Base.Internal.Output.Tabular.Utils
  ( 

    (<++>)
  , comment
  , tandem
  , exclusive
  , barStart
  , rest
  , nullDot
  , endSpine

  , concatBars

  ) where


import Text.PrettyPrint.HughesPJ        -- package: pretty



infixl 6 <++>

(<++>) :: Doc -> Doc -> Doc
a <++> b = a <> sizedText 8 "\t" <> b

comment :: String -> Doc
comment = text . ('!':)

tandem :: Doc -> Doc
tandem d    = char '*' <> d

exclusive :: Doc -> Doc
exclusive d = text "**" <> d



rest :: Doc
rest = char 'r'

nullDot :: Doc
nullDot = char '.'


columnRepeat :: Int -> Doc -> Doc
columnRepeat w d = step w
  where
    step n | n <= 0    = empty
           | n == 1    = d
           | otherwise = d <++> step (n-1)

    
endSpine :: Doc
endSpine = text "*-"

endSpines :: Int -> Doc
endSpines w 
    | w <= 0    = empty
    | w == 1    = endSpine
    | otherwise = endSpine <++> endSpines (w-1)

barStart :: Int -> Doc
barStart n = char '=' <> int n

barStarts :: Int -> Int -> Doc
barStarts w n = columnRepeat w (barStart n)

concatBars :: Int -> [Doc] -> Doc
concatBars _ []     = empty
concatBars w (x:xs) = step 1 x xs
  where
    step _ b []       = b $+$ endSpines w
    step n b (c:cs)   = barStarts w n $+$ b $+$ (step (n+1) c cs)

