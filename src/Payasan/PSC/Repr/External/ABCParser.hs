{-# LANGUAGE TemplateHaskell            #-}
{-# OPTIONS -Wall #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Payasan.PSC.Repr.External.ABCParser
-- Copyright   :  (c) Stephen Tetley 2015-2017
-- License     :  BSD3
--
-- Maintainer  :  stephen.tetley@gmail.com
-- Stability   :  unstable
-- Portability :  GHC
--
-- Parser for subset of ABC.
--
--------------------------------------------------------------------------------

module Payasan.PSC.Repr.External.ABCParser
  (
    abc
    
  -- * Aliases
  , ABCQBar
  , ABCQNoteGroup
  , ABCQElement
  , ABCQGrace1

  -- * Elementary parsers
  , pitch
  , accidental
  , pitchLetter
  , noteLength
  , tupletSpec
  , tie

  ) where


import Payasan.PSC.Repr.External.Syntax

import Payasan.PSC.Base.ABCLexer
import Payasan.PSC.Base.ABCCommon
import Payasan.PSC.Base.SyntaxCommon

import Text.Parsec                              -- package: parsec


import Language.Haskell.TH.Quote


--------------------------------------------------------------------------------
-- Quasiquote

abc :: QuasiQuoter
abc = QuasiQuoter
    { quoteExp = \s -> case parseABCPart s of
                         Left err -> error $ show err
                         Right xs -> dataToExpQ (const Nothing) xs
    , quoteType = \_ -> error "QQ - no Score Type"
    , quoteDec  = \_ -> error "QQ - no Score Decl"
    , quotePat  = \_ -> error "QQ - no Score Patt" 
    } 


--------------------------------------------------------------------------------
-- Aliases

-- The aliases are for transitory types - we define them 
-- alongside their respective parsers. 
--
-- Useless a user was developing an alternative parser, there
-- should be no need to consider these aliases.


type ABCQBar              = Bar         ABCPitch ABCNoteLength ()
type ABCQNoteGroup        = NoteGroup   ABCPitch ABCNoteLength ()
type ABCQElement          = Element     ABCPitch ABCNoteLength ()
type ABCQGrace1           = Grace1      ABCPitch ABCNoteLength

--------------------------------------------------------------------------------
-- Parser

parseABCPart :: String -> Either ParseError ABCSectionQuote
parseABCPart = runParser (fullParseABC qsection) () ""


qsection :: ABCParser ABCSectionQuote
qsection = (\bs -> ABCSectionQuote { getABCSection = bs}) <$> bars

bars :: ABCParser [ABCQBar]
bars = sepBy bar barline

barline :: ABCParser ()
barline = reservedOp "|"

bar :: ABCParser ABCQBar
bar = Bar <$> noteGroups 

noteGroups :: ABCParser [ABCQNoteGroup]
noteGroups = whiteSpace *> many noteGroup

noteGroup :: ABCParser ABCQNoteGroup
noteGroup = tuplet <|> (Atom <$> element)

element :: ABCParser ABCQElement
element = lexeme (rest <|> note <|> chord <|> graces)

rest :: ABCParser ABCQElement
rest = Rest <$> (char 'z' *> noteLength)

note :: ABCParser ABCQElement
note = (\p d t -> Note p d () t) <$> pitch <*> noteLength <*> tie

chord :: ABCParser ABCQElement
chord = (\ps d t -> Chord ps d () t)
          <$> squares (many1 pitch) <*> noteLength <*> tie

graces :: ABCParser ABCQElement
graces = Graces <$> braces (many1 grace1)


-- Cannot use parsecs count as ABC counts /deep leaves/.
--
tuplet :: ABCParser ABCQNoteGroup
tuplet = do 
   spec   <- tupletSpec
   notes  <- countedNoteGroups (tuplet_len spec)
   return $ Tuplet spec notes

countedNoteGroups :: Int -> ABCParser [ABCQNoteGroup]
countedNoteGroups n 
    | n > 0       = do { e  <- noteGroup
                       ; es <- countedNoteGroups (n - elementSize e)
                       ; return $ e:es
                       }
    | otherwise   = return []
                       
    

grace1 :: ABCParser ABCQGrace1
grace1 = Grace1 <$> pitch <*> noteLength
    <?> "grace1"


pitch :: ABCParser ABCPitch
pitch = ABCPitch <$> accidental <*> pitchLetter <*> octaveModifier





accidental :: ABCParser Accidental
accidental = accdntl <|> return NO_ACCIDENTAL
  where
    accdntl = choice $ 
                [ DBL_FLAT  <$ try (symbol "__")
                , FLAT      <$ symbol "_"
                , DBL_SHARP <$ try (symbol "^^")
                , SHARP     <$ symbol "^"
                , NATURAL   <$ symbol "="
                ]


pitchLetter :: ABCParser PitchLetter
pitchLetter = choice $
    [ CU <$ char 'C'
    , DU <$ char 'D'
    , EU <$ char 'E'
    , FU <$ char 'F'
    , GU <$ char 'G'
    , AU <$ char 'A'
    , BU <$ char 'B'
    , CL <$ char 'c'
    , DL <$ char 'd'
    , EL <$ char 'e'
    , FL <$ char 'f'
    , GL <$ char 'g'
    , AL <$ char 'a'
    , BL <$ char 'b'
    ]


octaveModifier :: ABCParser OctaveModifier
octaveModifier = octavehi <|> octavelo <|> return OveDefault
  where
    octavehi = (OveRaised  . length) <$> many1 (char '\'')
    octavelo = (OveLowered . length) <$> many1 (char ',')



noteLength :: ABCParser ABCNoteLength
noteLength = try (divd <|> multOrFrac) 
          <|> return DNL
  where
    divd        = Divd <$> divider
    multOrFrac  = do { n <- int 
                     ; opt <- optionMaybe (symbol "/" *> int)
                     ; case opt of
                         Nothing -> return $ Mult n
                         Just d  -> return $ Frac n d
                     }

divider :: ABCParser Int
divider = symbol "/" *> (int <|> moreDivs 2) 
       <?> "divider"
  where
    moreDivs ac = symbol "/" *> moreDivs (ac*2)
               <|> return ac
    

tupletSpec :: ABCParser TupletSpec
tupletSpec = symbol "(" *> int >>= step1
  where
    step1 n   =  do { t <- (symbol ":" *> int); step2 n t }
             <|> decode1 n
    step2 n t = do { x <- (symbol ":" *> int); return $ TupletSpec n t x }
             <|> decode2 n t

    decode1 2 = return $ TupletSpec 2 3 2
    decode1 3 = return $ TupletSpec 3 2 3
    decode1 4 = return $ TupletSpec 4 3 4
    decode1 6 = return $ TupletSpec 6 2 6
    decode1 8 = return $ TupletSpec 8 3 8
    decode1 n = fail $ "invalid tuplet spec (" ++ show n

    decode2 n t = return $ TupletSpec n t n


tie :: ABCParser Tie
tie = atie <|> notie
  where
    atie  = TIE <$ try (whiteSpace >> symbol "-")
    notie = return NO_TIE 

--------------------------------------------------------------------------------
-- Helpers


elementSize :: ABCQNoteGroup -> Int
elementSize (Tuplet spec _) = tuplet_len spec
elementSize _               = 1

