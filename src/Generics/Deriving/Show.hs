{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE IncoherentInstances #-} -- :-/
{-# LANGUAGE CPP #-}

module Generics.Deriving.Show (
  -- * Generic show class
    GShow(..)

  -- * Default definition
  , gshowsPrecdefault

  ) where


import Generics.Deriving.Base

--------------------------------------------------------------------------------
-- Generic show
--------------------------------------------------------------------------------

data Type = Rec | Tup | Pref | Inf String

class GShow' f where
  gshowsPrec' :: Type -> Int -> f a -> ShowS
  isNullary   :: f a -> Bool
  isNullary = error "generic show (isNullary): unnecessary case"

instance GShow' U1 where
  gshowsPrec' _ _ U1 = id
  isNullary _ = True

instance (GShow c) => GShow' (K1 i c) where
  gshowsPrec' _ n (K1 a) = gshowsPrec n a
  isNullary _ = False

-- No instances for P or Rec because gshow is only applicable to types of kind *

instance (GShow' a, Constructor c) => GShow' (M1 C c a) where
  gshowsPrec' _ n c@(M1 x) = 
    case fixity of
      Prefix    -> showParen (n > 10 && not (isNullary x)) 
                    ( showString (conName c) 
                    . if (isNullary x) then id else showChar ' '
                    . showBraces t (gshowsPrec' t 10 x))
      Infix _ m -> showParen (n > m) (showBraces t (gshowsPrec' t m x))
      where fixity = conFixity c
            t = if (conIsRecord c) then Rec else
                  case (conIsTuple c) of
                    Arity _ -> Tup
                    NoArity -> case fixity of
                                 Prefix    -> Pref
                                 Infix _ _ -> Inf (show (conName c))
            showBraces :: Type -> ShowS -> ShowS
            showBraces Rec     p = showChar '{' . p . showChar '}'
            showBraces Tup     p = showChar '(' . p . showChar ')'
            showBraces Pref    p = p
            showBraces (Inf _) p = p
  
  isNullary (M1 x) = isNullary x

instance (Selector s, GShow' a) => GShow' (M1 S s a) where
  gshowsPrec' t n s@(M1 x) | selName s == "" = showParen (n > 10)
                                                 (gshowsPrec' t n x)
                           | otherwise       =   showString (selName s)
                                               . showString " = "
                                               . gshowsPrec' t 0 x
  isNullary (M1 x) = isNullary x

instance (GShow' a) => GShow' (M1 D d a) where
  gshowsPrec' t n (M1 x) = gshowsPrec' t n x

instance (GShow' a, GShow' b) => GShow' (a :+: b) where
  gshowsPrec' t n (L1 x) = gshowsPrec' t n x
  gshowsPrec' t n (R1 x) = gshowsPrec' t n x

instance (GShow' a, GShow' b) => GShow' (a :*: b) where
  gshowsPrec' t@Rec     n (a :*: b) =
    gshowsPrec' t n     a . showString ", " . gshowsPrec' t n     b
  gshowsPrec' t@(Inf s) n (a :*: b) =
    gshowsPrec' t n     a . showString s    . gshowsPrec' t n     b
  gshowsPrec' t@Tup     n (a :*: b) =
    gshowsPrec' t n     a . showChar ','    . gshowsPrec' t n     b
  gshowsPrec' t@Pref    n (a :*: b) =
    gshowsPrec' t (n+1) a . showChar ' '    . gshowsPrec' t (n+1) b
  
  -- If we have a product then it is not a nullary constructor
  isNullary _ = False


class GShow a where 
  gshowsPrec :: Int -> a -> ShowS
  gshows :: a -> ShowS
  gshows = gshowsPrec 0
  gshow :: a -> String
  gshow x = gshows x ""
  

#ifdef __UHC__

{-# DERIVABLE GShow gshowsPrec gshowsPrecdefault #-}
deriving instance (GShow a) => GShow (Maybe a)

#else

instance (GShow a) => GShow (Maybe a) where
  gshowsPrec = t undefined where
    t :: (GShow a) => Rep0Maybe a x -> Int -> Maybe a -> ShowS
    t = gshowsPrecdefault

#endif

gshowsPrecdefault :: (Representable0 a rep0, GShow' rep0)
                  => rep0 x -> Int -> a -> ShowS
gshowsPrecdefault rep n x = gshowsPrec' Pref n (from0 x `asTypeOf` rep)


-- Base types instances
instance GShow Char   where gshowsPrec = showsPrec
instance GShow Int    where gshowsPrec = showsPrec
instance GShow Float  where gshowsPrec = showsPrec
instance GShow String where gshowsPrec = showsPrec
instance GShow Bool   where gshowsPrec = showsPrec

intersperse :: a -> [a] -> [a]
intersperse _ []    = []
intersperse _ [h]   = [h]
intersperse x (h:t) = h : x : (intersperse x t)

instance (GShow a) => GShow [a] where
  gshowsPrec _ l =   showChar '['
                   . foldr (.) id
                      (intersperse (showChar ',') (map (gshowsPrec 0) l))
                   . showChar ']'