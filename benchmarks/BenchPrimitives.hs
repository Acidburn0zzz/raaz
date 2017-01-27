{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE CPP                 #-}
{-# LANGUAGE RecordWildCards     #-}

-- | This module benchmarks all block function and shows the

import Control.Monad
import Criterion
import Criterion.Types hiding (measure)
import Criterion.Measurement
import Data.Int
import Text.PrettyPrint
import System.IO

import Raaz.Core
import Raaz.Cipher
import Raaz.Cipher.Internal
import Raaz.Hash.Internal
import Raaz.Random

import qualified Raaz.Hash.Sha1.Implementation.CPortable      as Sha1CP
import qualified Raaz.Hash.Sha256.Implementation.CPortable    as Sha256CP
import qualified Raaz.Hash.Sha512.Implementation.CPortable    as Sha512CP
import qualified Raaz.Cipher.AES.CBC.Implementation.CPortable as AesCbcCP
import qualified Raaz.Cipher.ChaCha20.Implementation.CPortable as ChaCha20CP

# ifdef HAVE_VECTOR_128
import qualified Raaz.Cipher.ChaCha20.Implementation.Vector128 as ChaCha20V128
# endif

# ifdef HAVE_VECTOR_256
import qualified Raaz.Cipher.ChaCha20.Implementation.Vector256 as ChaCha20V256
# endif

-- The total data processed
nBytes :: BYTES Int
nBytes = 32 * 1024

-- How many times to run each benchmark
nRuns :: Int64
nRuns = 10000

type Result            = (String, Measured)
type RaazBench         = (String, Benchmarkable)

allBench :: [RaazBench]
allBench =    [ memsetBench, randomnessBench ]
           ++ chacha20Benchs
           ++ aesBenchs
           ++ sha1Benchs
           ++ sha256Benchs
           ++ sha512Benchs

main :: IO ()
main = do results <- mapM runRaazBench allBench
          putStrLn $ "Buffer Size = " ++ show (fromIntegral nBytes :: Int)
          putStrLn $ "Iterations  = " ++ show nRuns
          putStrLn $ render $ vcat results


pprMeasured :: Measured -> Doc
pprMeasured (Measured{..}) = vcat
  [ text "time       " <+> eq <+> text (secs tm)
  , text "cycles     " <+> eq <+> double cy
  , text "rate       " <+> eq <+> double rt  <+> text "(bytes/sec)"
  , text "secs/byte  " <+> eq <+> double secB
  , text "cycles/byte" <+> eq <+> double cycB
  ]
  where tm    = measTime   / fromIntegral nRuns
        cy    = fromIntegral measCycles / fromIntegral nRuns
        bytes = fromIntegral nBytes
        secB  = tm    / bytes
        cycB  = cy    / bytes
        rt    = bytes / tm
        eq    = text "="


-------------  All benchmarks ---------------------------------------------

memsetBench :: RaazBench
memsetBench = ("memset", Benchmarkable $ memBench . fromIntegral )
  where memBench count = allocaBuffer nBytes $ \ ptr -> replicateM_ count (memset ptr 42 nBytes)


sha1Benchs :: [ RaazBench ]
sha1Benchs = [ hashBench Sha1CP.implementation ]

sha256Benchs :: [ RaazBench ]
sha256Benchs = [ hashBench Sha256CP.implementation ]

sha512Benchs :: [ RaazBench ]
sha512Benchs = [ hashBench Sha512CP.implementation ]


aesBenchs     :: [ RaazBench ]
aesBenchs      = [ encryptBench AesCbcCP.aes128cbcI
                 , decryptBench AesCbcCP.aes128cbcI
                 , encryptBench AesCbcCP.aes192cbcI
                 , decryptBench AesCbcCP.aes192cbcI
                 , encryptBench AesCbcCP.aes256cbcI
                 , decryptBench AesCbcCP.aes256cbcI
                 ]
chacha20Benchs :: [ RaazBench ]
chacha20Benchs = [ encryptBench ChaCha20CP.implementation
#               ifdef HAVE_VECTOR_256
                , encryptBench ChaCha20V256.implementation
#               endif
#               ifdef HAVE_VECTOR_128
                , encryptBench ChaCha20V128.implementation
#               endif
                ]


--------------------------- Helper functions ---------------------------------------------------------------------------

encryptBench :: Cipher c => Implementation c -> RaazBench
encryptBench si@(SomeCipherI impl) = (nm , Benchmarkable $ encrBench . fromIntegral)
  where encrBench count = allocBufferFor si sz $ \ ptr -> insecurely $ replicateM_ count $ encryptBlocks impl ptr sz
        nm = name si ++ "-encrypt"
        sz = atLeast nBytes


decryptBench :: Cipher c => Implementation c -> RaazBench
decryptBench si@(SomeCipherI impl) = (nm , Benchmarkable $ decrBench . fromIntegral)
  where decrBench count = allocBufferFor si sz $ \ ptr -> insecurely $ replicateM_ count $ decryptBlocks impl ptr sz
        nm = name si ++ "-decrypt"
        sz = atLeast nBytes

hashBench :: Hash h => Implementation h -> RaazBench
hashBench hi@(SomeHashI impl) = (nm, Benchmarkable $ compressBench . fromIntegral )
  where compressBench count = allocBufferFor hi sz $ \ ptr -> insecurely $ replicateM_ count $ compress impl ptr sz
        nm = name hi ++ "-compress"
        sz = atLeast nBytes

randomnessBench :: RaazBench
randomnessBench = ("random", Benchmarkable $ rand . fromIntegral)
  where rand count = allocaBuffer nBytes $ insecurely . replicateM_ count . fillIt
        fillIt :: Pointer -> RandomM ()
        fillIt = fillRandomBytes nBytes
runRaazBench :: RaazBench -> IO Doc
runRaazBench (nm, bm) = do
  hPutStr  stderr $ "running " ++ nm ++ " ..."
  (memt,x) <- measure bm nRuns
  hPutStrLn stderr $ "done."
  return $ text nm $+$ nest 8 (pprMeasured memt)
