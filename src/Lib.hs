{-# LANGUAGE BangPatterns #-}

module Lib
    ( runParTests
    , Test(..)
    , TestResolution(..)
    , TestData(..)
    ) where

import Data.Semigroup ((<>))
import Data.List ( isInfixOf )
import System.IO ( Handle, hGetLine )
import System.Exit ( ExitCode(..) )
import System.Process
    ( runInteractiveProcess, waitForProcess, ProcessHandle )
import System.IO.Error ( tryIOError )
import System.Directory ( doesDirectoryExist, doesPathExist, createDirectory )
import Control.Parallel.Strategies ( rpar, rseq, runEval, Eval )
import Control.Monad ( when, unless )
import Control.Exception ( throwIO, Exception )

newtype RunPreparationFailed = RunPreparationFailed String

instance Show RunPreparationFailed where
  show (RunPreparationFailed s) = s

instance Exception RunPreparationFailed

data TestData = RegularTest { testData  :: FilePath   --- File data to test on
                            , testStr   :: String     --- String to look occurences for
                            }
              | GenerateEnoentTest
              | GenerateReadErrTest
              | GenerateBadArgsTest
                deriving (Show)

data Test = Test { testInfo :: TestData
                 , testName :: String
                 } deriving (Show)

data TestResolution = TestResolution { testRunId     :: String
                                     , testRunResult :: Either String ()
                                     } deriving (Show)

formatTestName :: String
               -> String
formatTestName testId = "Test - " ++ show testId ++ ".data"

runSolution :: FilePath   -- Solution executable path
            -> [String]   -- List of argv
            -> IO (Handle, Handle, Handle, ProcessHandle)
runSolution path args = runInteractiveProcess path args Nothing Nothing

getStudentAnswer :: FilePath    -- Solution executable path
                 -> Test
                 -> IO (Either String (String, ExitCode))
getStudentAnswer solution (Test testInfo testId) = do
  case testInfo of
    RegularTest testData testQuery -> do
      let testPath = formatTestName testId
      writeFile testPath testData
      (ans, exitCode) <- getInternal [testPath, testQuery]
      return $ either Left (\ans -> Right (ans, exitCode)) (checkIO ans)
    GenerateEnoentTest -> do
      (ans, exitCode) <- getInternal ["<#%&>.txt", "the file doesn't exist wtf"]
      return $ Right ("No output in the test " ++ show testId ++ " expected", exitCode)
    GenerateReadErrTest -> do
      let testPath = formatTestName testId
      hasSuchDir <- doesPathExist testPath
      itIsADir <- doesDirectoryExist testPath
      when (hasSuchDir && not itIsADir) (throwIO $ RunPreparationFailed "Path exists and it is not directory")
      unless hasSuchDir $ createDirectory testPath
      (ans, exitCode) <- getInternal [testPath, "random string because directory expected"]
      return $ Right ("No output in the test " ++ show testId ++ " expected", exitCode)
    GenerateBadArgsTest -> do
      (ans, exitCode) <- getInternal [".", "foo", "bar", "baz"]
      return $ Right ("No output in the test " ++ show testId ++ " expected", exitCode)
  where
    getInternal args = do
      (inp, out, _, pid) <- runSolution solution args
      !ans      <- tryIOError $ hGetLine out
      !exitCode <- waitForProcess pid
      return (ans, exitCode)
    checkIO ans = either (makeError "Cannot read solution's output: ") pure ans
    makeError prefix err = Left (prefix ++ show err)

getRealAnswer :: Test
              -> IO (Either String Bool)
getRealAnswer (Test testInfo testId) = do
  case testInfo of
    RegularTest text query    -> return $ Right $ isInfixOf query text
    GenerateEnoentTest        -> return $ Left "No such test file"
    GenerateReadErrTest       -> return $ Left "Test file read error"
    GenerateBadArgsTest       -> return $ Left "Bad usage error"

runParTest :: FilePath   -- Path to student's executable
           -> Test       -- Given test
           -> Eval (IO TestResolution)
runParTest solution test = do
  studentResultIo <- rpar $ getStudentAnswer solution test
  ourAnswerIo <- rseq $ getRealAnswer test
  rseq studentResultIo
  let resolutionIo = makeResolution studentResultIo ourAnswerIo
  return resolutionIo

  where
    asResolution = TestResolution (testName test)

    makeResolution studentResultIo ourAnswerIo = do studentResult <- studentResultIo
                                                    ourAnswer <- ourAnswerIo
                                                    let resolution = compareSolutions studentResult ourAnswer
                                                    return resolution

    compareSolutions :: Either String (String, ExitCode)
                     -> Either String Bool
                     -> TestResolution
    compareSolutions (Left err) _ = asResolution (Left err)
    compareSolutions (Right (out, ExitSuccess)) (Left err) = asResolution (Left $ "Error expected, but student solution returned zero: " ++ err)
    compareSolutions (Right (out, ExitFailure err)) (Left err2) = asResolution (Right ())
    compareSolutions (Right (out, ExitFailure err)) (Right _) = asResolution (Left "Student's solution exited with error on a regular test")
    compareSolutions (Right (out, code)) (Right result)
      | result && (out == "Yes")      = asResolution $ Right ()
      | not result && (out == "No")   = asResolution $ Right ()
      | otherwise                     = asResolution $ Left $ do let firstLine = "Student answer: " ++ show out ++ " with code " ++ show code
                                                                 let secondLine = "Our answer: " ++ if result then "Yes" else "No"
                                                                 firstLine ++ "\n" ++ secondLine

runParTests :: FilePath
            -> [Test]
            -> IO [TestResolution]
runParTests solution tests = do
  let testEvals = runParTest solution <$> tests
  sequence $ runEval $ sequence testEvals
