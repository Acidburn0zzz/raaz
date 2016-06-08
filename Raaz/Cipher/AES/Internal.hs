{-# LANGUAGE DataKinds                        #-}
{-# LANGUAGE KindSignatures                   #-}
{-# LANGUAGE GeneralizedNewtypeDeriving       #-}
{-# LANGUAGE ForeignFunctionInterface         #-}
{-# LANGUAGE FlexibleInstances                #-}
{-# LANGUAGE MultiParamTypeClasses            #-}
{-# LANGUAGE TypeFamilies                     #-}

module Raaz.Cipher.AES.Internal
       ( AES(..), WORD, TUPLE
       , KEY128, KEY192, KEY256
       , EKEY128, EKEY192, EKEY256, IV
       , aes128cbc, aes192cbc, aes256cbc
       , aes128ctr
       ) where

import Data.String
import Data.Word

import Foreign.Ptr      (castPtr )
import Foreign.Storable (Storable, poke)
import GHC.TypeLits


import Raaz.Core
import Raaz.Cipher.Internal

--------------- Basic types associated with AES -------------

-- | The AES cipher.
data AES (n :: Nat) (mode :: CipherMode) = AES

-- | The basic word used in AES.
type WORD    = BE Word32

-- | A tuple of AES words.
type TUPLE n = Tuple n WORD

-- | Key used for AES-128
newtype KEY128  = KEY128  (TUPLE 4)  deriving (Storable, EndianStore)

-- | Key used for AES-128
newtype KEY192  = KEY192  (TUPLE 6)  deriving (Storable, EndianStore)

-- | Key used for AES-128
newtype KEY256  = KEY256  (TUPLE 8)  deriving (Storable, EndianStore)

instance Encodable KEY128

instance Encodable KEY192

instance Encodable KEY256

-- | Expects in base 16
instance IsString KEY128 where
  fromString = fromBase16

-- | Shows in base 16
instance Show KEY128 where
  show = showBase16

-- | Expects in  base 16
instance IsString KEY192 where
  fromString = fromBase16

-- | Shows in base 16
instance Show KEY192 where
  show = showBase16

-- | Expects in base 16
instance IsString KEY256 where
  fromString = fromBase16

-- | Shows in base 16
instance Show KEY256 where
  show = showBase16

--------------- AES CBC ---------------------------------

-- | The IV used by the CBC mode.
newtype IV  = IV (TUPLE 4) deriving (Storable, EndianStore)

instance Encodable IV

-- | Expects in base16.
instance IsString IV where
  fromString = fromBase16

-- | Shown as a its base16 encoding.
instance Show IV where
  show = showBase16

----------------- AES 128 CBC ------------------------------

-- | Smart constructors for AES 128 cbc.
aes128cbc :: AES 128 CBC
aes128cbc = AES

-- | The 128-bit aes cipher in cbc mode.
instance Primitive (AES 128 CBC) where
  blockSize _ = BYTES 16
  type Implementation (AES 128 CBC) = SomeCipherI (AES 128 CBC)

-- | Key is @(`KEY128`,`IV`)@ pair.
instance Symmetric (AES 128 CBC) where
  type Key (AES 128 CBC) = (KEY128,IV)

instance Cipher (AES 128 CBC)

----------------- AES 192 CBC --------------------------------

-- | Smart  constructor for AES 192 cbc.
aes192cbc :: AES 192 CBC
aes192cbc = AES

-- | The 192-bit aes cipher in cbc mode.
instance Primitive (AES 192 CBC) where
  blockSize _ = BYTES 16
  type Implementation (AES 192 CBC) = SomeCipherI (AES 192 CBC)

-- | Key is @(`KEY192`,`IV`)@ pair.
instance Symmetric (AES 192 CBC) where
  type Key (AES 192 CBC) = (KEY192,IV)

instance Cipher (AES 192 CBC)

------------------- AES 256 CBC -----------------------------

-- | Smart constructor for AES 256 cbc.
aes256cbc :: AES 256 CBC
aes256cbc = AES

-- | The 256-bit aes cipher in cbc mode.
instance Primitive (AES 256 CBC) where
  blockSize _ = BYTES 16
  type Implementation (AES 256 CBC) = SomeCipherI (AES 256 CBC)

-- | Key is @(`KEY256`,`IV`)@ pair.
instance Symmetric (AES 256 CBC) where
  type Key (AES 256 CBC) = (KEY256,IV)

instance Cipher (AES 256 CBC)


------------------- AES CTR mode ---------------------------

-- | Smart constructors for AES 128 ctr.
aes128ctr :: AES 128 CTR
aes128ctr = AES

--------------  Memory for storing extended keys ---------

newtype EKEY128 = EKEY128 (TUPLE 44) deriving (Storable, EndianStore)
newtype EKEY192 = EKEY192 (TUPLE 52) deriving (Storable, EndianStore)
newtype EKEY256 = EKEY256 (TUPLE 60) deriving (Storable, EndianStore)

instance Initialisable (MemoryCell EKEY128) KEY128 where
  initialise k = withPointer $ pokeAndExpand k (c_expand 4)

instance Initialisable (MemoryCell EKEY192) KEY192 where
  initialise k = withPointer $ pokeAndExpand k (c_expand 6)

instance Initialisable (MemoryCell EKEY256) KEY256 where
  initialise k = withPointer $ pokeAndExpand k (c_expand 8)

foreign import ccall unsafe
  "raaz/cipher/aes/common.h raazAESExpand"
  c_expand :: Int -> Pointer -> IO ()

-- | Poke a key and expand it with the given routine.
pokeAndExpand :: Storable k
              => k                   -- ^ key to poke
              -> (Pointer -> IO ())  -- ^ expansion algorithm
              -> Pointer             -- ^ buffer pointer.
              -> IO ()
pokeAndExpand k expander ptr = poke (castPtr ptr) k >> expander ptr