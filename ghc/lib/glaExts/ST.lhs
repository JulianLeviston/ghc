%
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1996
%
\section[module_ST]{The State Transformer Monad, @ST@}

\begin{code}
{-# OPTIONS -fno-implicit-prelude #-}

module ST (

	-- ToDo: review this interface; I'm avoiding gratuitous changes for now
	--			SLPJ Jan 97


	ST,

        -- ST is one, so you'll likely need some Monad bits
        module Monad,

	thenST, seqST, returnST, listST, fixST, runST, unsafeInterleaveST,
        mapST, mapAndUnzipST,
         -- the lazy variant
	-- returnLazyST, thenLazyST, seqLazyST,

	MutableVar,
	newVar, readVar, writeVar, sameVar,

	MutableArray,
	newArray, readArray, writeArray, sameMutableArray

    ) where

import IOBase	( error )	-- [Source not needed]
import ArrBase
import STBase
import UnsafeST	( unsafeInterleaveST )
import PrelBase	( Int, Bool, ($), ()(..) )
import GHC	( newArray#, readArray#, writeArray#, sameMutableArray#, sameMutableByteArray# )
import Monad

\end{code}

%*********************************************************
%*							*
\subsection{Variables}
%*							*
%*********************************************************

\begin{code}
-- in ArrBase: type MutableVar s a = MutableArray s Int a

newVar   :: a -> ST s (MutableVar s a)
readVar  :: MutableVar s a -> ST s a
writeVar :: MutableVar s a -> a -> ST s ()
sameVar  :: MutableVar s a -> MutableVar s a -> Bool

newVar init = ST $ \ s# ->
    case (newArray# 1# init s#)     of { StateAndMutableArray# s2# arr# ->
    STret s2# (MutableArray vAR_IXS arr#) }
  where
    vAR_IXS = error "newVar: Shouldn't access `bounds' of a MutableVar\n"

readVar (MutableArray _ var#) = ST $ \ s# ->
    case readArray# var# 0# s#	of { StateAndPtr# s2# r ->
    STret s2# r }

writeVar (MutableArray _ var#) val = ST $ \ s# ->
    case writeArray# var# 0# val s# of { s2# ->
    STret s2# () }

sameVar (MutableArray _ var1#) (MutableArray _ var2#)
  = sameMutableArray# var1# var2#
\end{code}


\begin{code}
sameMutableArray     :: MutableArray s ix elt -> MutableArray s ix elt -> Bool
sameMutableByteArray :: MutableByteArray s ix -> MutableByteArray s ix -> Bool

sameMutableArray (MutableArray _ arr1#) (MutableArray _ arr2#)
  = sameMutableArray# arr1# arr2#

sameMutableByteArray (MutableByteArray _ arr1#) (MutableByteArray _ arr2#)
  = sameMutableByteArray# arr1# arr2#
\end{code}
