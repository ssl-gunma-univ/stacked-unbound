module Main where

import Lib

import Unbound.LocallyNameless

import Control.Applicative
import Control.Arrow ((+++))
import Control.Monad
import Control.Monad.Trans.Error
import Control.Monad.Trans.Maybe

import Text.Parsec hiding (Empty, (<|>))
import Text.Parsec.Language (haskellDef)
import qualified Text.Parsec.Token as P

import qualified Text.PrettyPrint as PP
import Text.PrettyPrint (Doc, (<+>))

data Term
  = Var (Name Term)
  | App Term Term
  | Lam (Bind (Name Term) Term)
  deriving (Show)

$(derive [''Term])

instance Alpha Term

instance Subst Term Term where
  isvar (Var v) = Just (SubstName v)
  isvar _ = Nothing

lam :: String -> Term -> Term
lam x t = Lam $ bind (string2Name x) t

var :: String -> Term
var = Var . string2Name

-- A convenient synonym for mzero
done :: MonadPlus m => m a
done = mzero

step :: Term -> MaybeT FreshM Term
step (Var _) = done
step (Lam _) = done
step (App (Lam b) t2) = do
  (x, t1) <- unbind b
  return $ subst x t2 t1
step (App t1 t2) = App <$> step t1 <*> pure t2 <|> App <$> pure t1 <*> step t2

tc :: (Monad m, Functor m) => (a -> MaybeT m a) -> (a -> m a)
tc f a = do
  ma' <- runMaybeT (f a)
  case ma' of
    Just a' -> tc f a'
    Nothing -> return a

eval :: Term -> Term
eval x = runFreshM (tc step x)

{- Parsing -}
lexer = P.makeTokenParser haskellDef

parens = P.parens lexer

brackets = P.brackets lexer

ident = P.identifier lexer

parseTerm = parseAtom `chainl1` (pure App)

parseAtom =
  parens parseTerm <|> var <$> ident <|> lam <$> (brackets ident) <*> parseTerm

runTerm :: String -> Either ParseError Term
runTerm = (id +++ eval) . parse parseTerm ""
    {-
class Pretty' p where
  ppr' :: (Applicative m, Fresh m) => p -> m Doc

instance Pretty' Term where
  ppr' (Var x) = return . PP.text . show $ x
  ppr' (App t1 t2) = PP.parens <$> ((<+>) <$> ppr' t1 <*> ppr' t2)
  ppr' (Lam b) = do
    (x, t) <- unbind b
    ((PP.brackets . PP.text . show $ x) <+>) <$> ppr' t
    -}

{-Pretty-printing and LFresh-}
class Pretty p where
  ppr :: (Applicative m, LFresh m) => p -> m Doc

instance Pretty Term where
  ppr (Var x) = return . PP.text . show $ x
  ppr (App t1 t2) = PP.parens <$> ((<+>) <$> ppr t1 <*> ppr t2)
  ppr (Lam b) =
    lunbind b $ \(x, t) -> ((PP.brackets . PP.text . show $ x) <+>) <$> ppr t

main :: IO ()
main = someFunc
