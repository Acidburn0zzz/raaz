{-# LANGUAGE ForeignFunctionInterface   #-}
-- | The portable C-implementation of SHA1
module Raaz.Hash.Sha512.Implementation.CPortable
       ( implementation, cPortable
       ) where

import Foreign.Ptr                ( Ptr )
import Raaz.Core
import Raaz.Hash.Internal
import Raaz.Hash.Sha.Util
import Raaz.Hash.Sha512.Internal

-- | The portable C implementation of SHA512.
implementation :: Implementation SHA512
implementation =  SomeHashI cPortable

cPortable :: HashI SHA512 (HashMemory SHA512)
cPortable = shaImplementation
            "sha512-cportable"
            "Sha512 Implementation using portable C and Haskell FFI"
            c_sha512_compress length128Write

foreign import ccall unsafe
  "raaz/hash/sha512/portable.h raazHashSha512PortableCompress"
  c_sha512_compress  :: Pointer -> Int -> Ptr SHA512 -> IO ()
