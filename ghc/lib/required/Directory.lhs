%
% (c) The AQUA Project, Glasgow University, 1994-1997
%
\section[Directory]{Directory interface}

A directory contains a series of entries, each of which is a named
reference to a file system object (file, directory etc.).  Some
entries may be hidden, inaccessible, or have some administrative
function (e.g. "." or ".." under POSIX), but in this standard all such
entries are considered to form part of the directory contents.
Entries in sub-directories are not, however, considered to form part
of the directory contents.

Each file system object is referenced by a {\em path}.  There is
normally at least one absolute path to each file system object.  In
some operating systems, it may also be possible to have paths which
are relative to the current directory.

\begin{code}
{-# OPTIONS -#include <sys/stat.h> #-}
module Directory 
   ( 
    Permissions(Permissions),

    createDirectory, 
    removeDirectory, 
    renameDirectory, 
    getDirectoryContents,
    getCurrentDirectory, 
    setCurrentDirectory,

    removeFile, 
    renameFile, 

    doesFileExist,
    doesDirectoryExist,
    getPermissions, 
    setPermissions,
    getModificationTime
   ) where

import PrelBase
import Foreign
import IOBase
import STBase
import UnsafeST		( unsafePerformPrimIO )
import ArrBase
import PackBase		( unpackNBytesST )
import Time             ( ClockTime(..) )

\end{code}

%*********************************************************
%*							*
\subsection{Signatures}
%*							*
%*********************************************************

\begin{code}
createDirectory 	:: FilePath -> IO ()
removeDirectory 	:: FilePath -> IO ()
removeFile 		:: FilePath -> IO ()
renameDirectory 	:: FilePath -> FilePath -> IO ()
renameFile 		:: FilePath -> FilePath -> IO ()
getDirectoryContents 	:: FilePath -> IO [FilePath]
getCurrentDirectory 	:: IO FilePath
setCurrentDirectory 	:: FilePath -> IO ()
doesFileExist           :: FilePath -> IO Bool
doesDirectoryExist      :: FilePath -> IO Bool
getPermissions          :: FilePath -> IO Permissions
setPermissions          :: FilePath -> Permissions -> IO ()
getModificationTime     :: FilePath -> IO ClockTime
\end{code}


%*********************************************************
%*							*
\subsection{Permissions}
%*							*
%*********************************************************

The @Permissions@ type is used to record whether certain
operations are permissible on a file/directory:
[to whom? - owner/group/world - the Report don't say much]

\begin{code}
data Permissions
 = Permissions {
    readable,   writeable, 
    executable, searchable :: Bool 
   } deriving (Eq, Ord, Read, Show)
\end{code}

%*********************************************************
%*							*
\subsection{Implementation}
%*							*
%*********************************************************

@createDirectory dir@ creates a new directory {\em dir} which is
initially empty, or as near to empty as the operating system
allows.

The operation may fail with:

\begin{itemize}
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EROFS, EACCES]@
\item @isAlreadyExistsError@ / @AlreadyExists@
The operand refers to a directory that already exists.  
@ [EEXIST]@
\item @HardwareFault@
A physical I/O error has occurred.
@ [EIO]@
\item @InvalidArgument@
The operand is not a valid directory name.
@[ENAMETOOLONG, ELOOP]@
\item @NoSuchThing@
There is no path to the directory. 
@[ENOENT, ENOTDIR]@
\item @ResourceExhausted@
Insufficient resources (virtual memory, process file descriptors,
physical disk space, etc.) are available to perform the operation.
@[EDQUOT, ENOSPC, ENOMEM, EMLINK]@
\item @InappropriateType@
The path refers to an existing non-directory object.
@[EEXIST]@
\end{itemize}

\begin{code}
createDirectory path =
    _ccall_ createDirectory path    `thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail "createDirectory"
\end{code}

@removeDirectory dir@ removes an existing directory {\em dir}.  The
implementation may specify additional constraints which must be
satisfied before a directory can be removed (e.g. the directory has to
be empty, or may not be in use by other processes).  It is not legal
for an implementation to partially remove a directory unless the
entire directory is removed. A conformant implementation need not
support directory removal in all situations (e.g. removal of the root
directory).

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
[@EIO@]
\item @InvalidArgument@
The operand is not a valid directory name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExist@ / @NoSuchThing@
The directory does not exist. 
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EROFS, EACCES, EPERM]@
\item @UnsatisfiedConstraints@
Implementation-dependent constraints are not satisfied.  
@[EBUSY, ENOTEMPTY, EEXIST]@
\item @UnsupportedOperation@
The implementation does not support removal in this situation.
@[EINVAL]@
\item @InappropriateType@
The operand refers to an existing non-directory object.
@[ENOTDIR]@
\end{itemize}

\begin{code}
removeDirectory path =
    _ccall_ removeDirectory path    `thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail "removeDirectory"
\end{code}

@removeFile file@ removes the directory entry for an existing file
{\em file}, where {\em file} is not itself a directory. The
implementation may specify additional constraints which must be
satisfied before a file can be removed (e.g. the file may not be in
use by other processes).

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @InvalidArgument@
The operand is not a valid file name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExist@ / @NoSuchThing@
The file does not exist. 
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EROFS, EACCES, EPERM]@
\item @UnsatisfiedConstraints@
Implementation-dependent constraints are not satisfied.  
@[EBUSY]@
\item @InappropriateType@
The operand refers to an existing directory.
@[EPERM, EINVAL]@
\end{itemize}

\begin{code}
removeFile path =
    _ccall_ removeFile path `thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail "removeFile"
\end{code}

@renameDirectory old@ {\em new} changes the name of an existing
directory from {\em old} to {\em new}.  If the {\em new} directory
already exists, it is atomically replaced by the {\em old} directory.
If the {\em new} directory is neither the {\em old} directory nor an
alias of the {\em old} directory, it is removed as if by
$removeDirectory$.  A conformant implementation need not support
renaming directories in all situations (e.g. renaming to an existing
directory, or across different physical devices), but the constraints
must be documented.

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @InvalidArgument@
Either operand is not a valid directory name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExistError@ / @NoSuchThing@
The original directory does not exist, or there is no path to the target.
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EROFS, EACCES, EPERM]@
\item @ResourceExhausted@
Insufficient resources are available to perform the operation.  
@[EDQUOT, ENOSPC, ENOMEM, EMLINK]@
\item @UnsatisfiedConstraints@
Implementation-dependent constraints are not satisfied.
@[EBUSY, ENOTEMPTY, EEXIST]@
\item @UnsupportedOperation@
The implementation does not support renaming in this situation.
@[EINVAL, EXDEV]@
\item @InappropriateType@
Either path refers to an existing non-directory object.
@[ENOTDIR, EISDIR]@
\end{itemize}

\begin{code}
renameDirectory opath npath =
    _ccall_ renameDirectory opath npath	`thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail "renameDirectory"
\end{code}

@renameFile old@ {\em new} changes the name of an existing file system
object from {\em old} to {\em new}.  If the {\em new} object already
exists, it is atomically replaced by the {\em old} object.  Neither
path may refer to an existing directory.  A conformant implementation
need not support renaming files in all situations (e.g. renaming
across different physical devices), but the constraints must be
documented.

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @InvalidArgument@
Either operand is not a valid file name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExistError@ / @NoSuchThing@
The original file does not exist, or there is no path to the target.
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EROFS, EACCES, EPERM]@
\item @ResourceExhausted@
Insufficient resources are available to perform the operation.  
@[EDQUOT, ENOSPC, ENOMEM, EMLINK]@
\item @UnsatisfiedConstraints@
Implementation-dependent constraints are not satisfied.
@[EBUSY]@
\item @UnsupportedOperation@
The implementation does not support renaming in this situation.
@[EXDEV]@
\item @InappropriateType@
Either path refers to an existing directory.
@[ENOTDIR, EISDIR, EINVAL, EEXIST, ENOTEMPTY]@
\end{itemize}

\begin{code}
renameFile opath npath =
    _ccall_ renameFile opath npath  `thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail	"renameFile"
\end{code}

@getDirectoryContents dir@ returns a list of {\em all} entries
in {\em dir}. 

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @InvalidArgument@
The operand is not a valid directory name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExistError@ / @NoSuchThing@
The directory does not exist.
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EACCES]@
\item @ResourceExhausted@
Insufficient resources are available to perform the operation.
@[EMFILE, ENFILE]@
\item @InappropriateType@
The path refers to an existing non-directory object.
@[ENOTDIR]@
\end{itemize}

\begin{code}
getDirectoryContents path =
    _ccall_ getDirectoryContents path	`thenIO_Prim` \ ptr ->
    if ptr == ``NULL'' then
        constructErrorAndFail "getDirectoryContents"
    else
	stToIO (getEntries ptr 0)	>>= \ entries ->
	_ccall_ free ptr		`thenIO_Prim` \ () ->
	return entries
  where
    getEntries :: Addr -> Int -> PrimIO [FilePath]
    getEntries ptr n =
        _casm_ ``%r = ((char **)%0)[%1];'' ptr n    >>= \ str ->
        if str == ``NULL'' then 
            return []
        else
            _ccall_ strlen str			    >>= \ len ->
	    unpackNBytesST str len		    >>= \ entry ->
            _ccall_ free str			    >>= \ () ->
            getEntries ptr (n+1)		    >>= \ entries ->
	    return (entry : entries)
\end{code}

If the operating system has a notion of current directories,
@getCurrentDirectory@ returns an absolute path to the
current directory of the calling process.

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @isDoesNotExistError@ / @NoSuchThing@
There is no path referring to the current directory.
@[EPERM, ENOENT, ESTALE...]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EACCES]@
\item @ResourceExhausted@
Insufficient resources are available to perform the operation.
\item @UnsupportedOperation@
The operating system has no notion of current directory.
\end{itemize}

\begin{code}
getCurrentDirectory =
    _ccall_ getCurrentDirectory	    `thenIO_Prim` \ str ->
    if str /= ``NULL'' then
        _ccall_ strlen str		`thenIO_Prim` \ len ->
        stToIO (unpackNBytesST len str)	>>=	      \ pwd ->
        _ccall_ free str		`thenIO_Prim` \ () ->
        return pwd
    else
        constructErrorAndFail "getCurrentDirectory"
\end{code}

If the operating system has a notion of current directories,
@setCurrentDirectory dir@ changes the current
directory of the calling process to {\em dir}.

The operation may fail with:
\begin{itemize}
\item @HardwareFault@
A physical I/O error has occurred.
@[EIO]@
\item @InvalidArgument@
The operand is not a valid directory name.
@[ENAMETOOLONG, ELOOP]@
\item @isDoesNotExistError@ / @NoSuchThing@
The directory does not exist.
@[ENOENT, ENOTDIR]@
\item @isPermissionError@ / @PermissionDenied@
The process has insufficient privileges to perform the operation.
@[EACCES]@
\item @UnsupportedOperation@
The operating system has no notion of current directory, or the
current directory cannot be dynamically changed.
\item @InappropriateType@
The path refers to an existing non-directory object.
@[ENOTDIR]@
\end{itemize}

\begin{code}
setCurrentDirectory path =
    _ccall_ setCurrentDirectory path	`thenIO_Prim` \ rc ->
    if rc == 0 then
        return ()
    else
        constructErrorAndFail "setCurrentDirectory"
\end{code}



\begin{code}
--doesFileExist :: FilePath -> IO Bool
doesFileExist name =
  _ccall_ access name (``F_OK''::Int)	    `thenIO_Prim` \ rc ->
  return (rc == 0)

--doesDirectoryExist :: FilePath -> IO Bool
doesDirectoryExist name = 
 (getFileStatus name >>= \ st -> return (isDirectory st))  
   `catch` 
 (\ _ -> return False)

--getModificationTime :: FilePath -> IO ClockTime
getModificationTime name =
 getFileStatus name >>= \ st ->
 modificationTime st

--getPermissions :: FilePath -> IO Permissions
getPermissions name =
  getFileStatus name >>= \ st ->
  let
   fm = fileMode st
   isect v = intersectFileMode v fm == v
  in
  return (
    Permissions {
      readable   = isect ownerReadMode,
      writeable  = isect ownerWriteMode,
      executable = not (isDirectory st)   && isect ownerExecuteMode,
      searchable = not (isRegularFile st) && isect ownerExecuteMode
    }
  )

--setPermissions :: FilePath -> Permissions -> IO ()
setPermissions name (Permissions r w e s) = 
    let
     read#  = case (if r then ownerReadMode else ``0'') of { W# x# -> x# }
     write# = case (if w then ownerWriteMode else ``0'') of { W# x# -> x# }
     exec#  = case (if e || s then ownerExecuteMode else ``0'') of { W# x# -> x# }

     mode  = I# (word2Int# (read# `or#` write# `or#` exec#))
    in
    _ccall_ chmod name mode			    `thenIO_Prim` \ rc ->
    if rc == 0 then
	return ()
    else
	fail (IOError Nothing SystemError "Directory.setPermissions")

\end{code}


(Sigh)..copied from Posix.Files to avoid dep. on posix library

\begin{code}
type FileStatus = ByteArray Int

getFileStatus :: FilePath -> IO FileStatus
getFileStatus name =
    newCharArray (0,``sizeof(struct stat)'')        `thenIO_Prim` \ bytes ->
    _casm_ ``%r = stat(%0,(struct stat *)%1);'' name bytes
						    `thenIO_Prim` \ rc ->
    if rc == 0 then
	unsafeFreezeByteArray bytes          	    `thenIO_Prim` \ stat ->
	return stat
    else
	fail (IOError Nothing SystemError "Directory.getFileStatus")

modificationTime :: FileStatus -> IO ClockTime
modificationTime stat =
    malloc1					           `thenIO_Prim` \ i1 ->
    _casm_ ``((unsigned long *)%1)[0] = ((struct stat *)%0)->st_mtime;'' stat i1 `thenIO_Prim` \ () ->
    cvtUnsigned i1                                         `thenIO_Prim` \ secs ->
    return (TOD secs 0)
  where
    malloc1 = ST $ \ s# ->
	case newIntArray# 1# s# of 
          StateAndMutableByteArray# s2# barr# -> 
		STret s2# (MutableByteArray bnds barr#)

    bnds = (0,1)
    -- The C routine fills in an unsigned word.  We don't have `unsigned2Integer#,'
    -- so we freeze the data bits and use them for an MP_INT structure.  Note that
    -- zero is still handled specially, although (J# 1# 1# (ptr to 0#)) is probably
    -- acceptable to gmp.

    cvtUnsigned (MutableByteArray _ arr#) = ST $ \ s# ->
	case readIntArray# arr# 0# s# of 
	  StateAndInt# s2# r# ->
            if r# ==# 0# then
                STret s2# 0
            else
                case unsafeFreezeByteArray# arr# s2# of
                  StateAndByteArray# s3# frozen# -> 
			STret s3# (J# 1# 1# frozen#)

isDirectory :: FileStatus -> Bool
isDirectory stat = unsafePerformPrimIO $
    _casm_ ``%r = S_ISDIR(((struct stat *)%0)->st_mode);'' stat >>= \ rc ->
    return (rc /= 0)

isRegularFile :: FileStatus -> Bool
isRegularFile stat = unsafePerformPrimIO $
    _casm_ ``%r = S_ISREG(((struct stat *)%0)->st_mode);'' stat >>= \ rc ->
    return (rc /= 0)


\end{code}

\begin{code}
type FileMode = Word
ownerReadMode :: FileMode
ownerReadMode = ``S_IRUSR''

ownerWriteMode :: FileMode
ownerWriteMode = ``S_IWUSR''

ownerExecuteMode :: FileMode
ownerExecuteMode = ``S_IXUSR''

intersectFileMode :: FileMode -> FileMode -> FileMode
intersectFileMode (W# m1#) (W# m2#) = W# (m1# `and#` m2#)

fileMode :: FileStatus -> FileMode
fileMode stat = unsafePerformPrimIO $
    _casm_ ``%r = ((struct stat *)%0)->st_mode;'' stat >>= \ mode ->
    return mode

\end{code}
