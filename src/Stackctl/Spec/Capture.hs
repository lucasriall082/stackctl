module Stackctl.Spec.Capture
  ( CaptureOptions(..)
  , runCaptureOptions
  , runCapture
  ) where

import Stackctl.Prelude

import Options.Applicative
import Stackctl.AWS
import Stackctl.AWS.Scope
import Stackctl.DirectoryOption (HasDirectoryOption(..))
import Stackctl.Spec.Generate
import Stackctl.StackSpec

data CaptureOptions = CaptureOptions
  { scoAccountName :: Maybe Text
  , scoTemplatePath :: Maybe FilePath
  , scoStackPath :: Maybe FilePath
  , scoDepends :: Maybe [StackName]
  , scoTemplateFormat :: TemplateFormat
  , scoStackName :: StackName
  }

-- brittany-disable-next-binding

runCaptureOptions :: Parser CaptureOptions
runCaptureOptions = CaptureOptions
    <$> optional (strOption
      (  short 'n'
      <> long "account-name"
      <> metavar "NAME"
      <> help "Account name to use in generated files"
      ))
    <*> optional (strOption
      (  short 't'
      <> long "template-path"
      <> metavar "PATH"
      <> help "Write Template to PATH. Default is based on STACK"
      ))
    <*> optional (strOption
      (  short 'p'
      <> long "path"
      <> metavar "PATH"
      <> help "Write specification to PATH. Default is based on STACK"
      ))
    <*> optional (some (StackName <$> strOption
      (  long "depend"
      <> metavar "STACK"
      <> help "Add a dependency on STACK"
      )))
    <*> flag TemplateFormatYaml TemplateFormatJson
      (  long "no-flip"
      <> help "Don't flip JSON templates to Yaml"
      )
    <*> (StackName <$> argument str
      (  metavar "STACK"
      <> help "Name of deployed Stack to capture"
      ))

runCapture
  :: ( MonadMask m
     , MonadUnliftIO m
     , MonadResource m
     , MonadLogger m
     , MonadReader env m
     , HasAwsScope env
     , HasAwsEnv env
     , HasDirectoryOption env
     )
  => CaptureOptions
  -> m ()
runCapture CaptureOptions {..} = do
  dir <- view directoryOptionL
  stack <- awsCloudFormationDescribeStack scoStackName
  template <- awsCloudFormationGetTemplate scoStackName

  let
    setScopeName scope =
      maybe scope (\name -> scope { awsAccountName = name }) scoAccountName

  void $ local (awsScopeL %~ setScopeName) $ generate Generate
    { gOutputDirectory = dir
    , gTemplatePath = scoTemplatePath
    , gTemplateFormat = scoTemplateFormat
    , gStackPath = scoStackPath
    , gStackName = scoStackName
    , gDescription = stackDescription stack
    , gDepends = scoDepends
    , gActions = Nothing
    , gParameters = parameters stack
    , gCapabilities = capabilities stack
    , gTags = tags stack
    , gTemplateBody = templateBodyFromValue template
    }
