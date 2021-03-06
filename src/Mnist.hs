module Mnist where

import Data.List (nub, sort, intercalate)
import Codec.Compression.GZip (decompress)
import qualified Data.ByteString.Lazy as BS
import Numeric.LinearAlgebra (vector, Vector, R, Z, reshape, Matrix, toList, toRows, fromRows)

-- | typeclass that represents a dataset
class DataSet a where
  groupByLabel :: a -> [Matrix R]
  distinctLabels :: a -> [R]
  dataLabel :: a -> [(Vector R, R)]  -- pair the data and label for each sample
  -- oneHotLabel :: a -> Matrix Z

img_header_size = 16
label_header_size = 8
width = 28
img_size = 784

-- labeled data consists of data and their label
data LabeledData = LabeledData
    { dat :: !(Matrix R)  -- this has num_data >< data_dimension
    , label :: !(Vector R)
    }

-- define LabeledData as instance of DataSet typeclass
instance DataSet LabeledData where
    distinctLabels = sort . nub . toList . label
    groupByLabel ld = [
        -- extract index that matches the label, and cherrypicks them from data rows
        fromRows [dataRows !! idx | idx <- extractIdx lab]
        | lab <- distinctLabels ld ]
      where
        dataRows = toRows $ dat ld  -- represent matrix as list of rows
        labels = toList $ label ld  -- represent vector to list of values
        labelIdx = zip labels [0..]  -- zip it with index
        extractIdx targetLabel = map snd $ filter ((== targetLabel) . fst) labelIdx
    dataLabel ld = zip (toRows $ dat ld) (toList $ label ld)

-- mnist dataset consists of train set and a test set
data Mnist = Mnist
    { trainData :: LabeledData
    , testData :: LabeledData
    }

-- render a single number
render :: Vector R -> String
render s = intercalate "\n" $ splitted $ map (intensity . floor) (toList s)  -- insert \n every 28 chars
  where
    chars = " ..:oO0@"
    intensity n = chars !! (n * length chars `div` 256)
    splitted :: [a] -> [[a]]
    splitted [] = []
    splitted v = (take width v) : (splitted $ drop width v)  -- split by 28

-- convert byteString to vector -- in this case, bytestring is read as numbers byte by byte
byteStringToVector :: BS.ByteString -> Vector R
byteStringToVector = vector . map fromIntegral . BS.unpack

readDataFile :: String -> IO BS.ByteString
readDataFile filepath = decompress <$> BS.readFile filepath

-- make label data represented as Vector
makeLabelData :: BS.ByteString -> Vector R
makeLabelData = byteStringToVector . BS.drop 8  -- 8-byte header

-- make image data represented as Matrix
makeImgData :: BS.ByteString -> Matrix R
makeImgData = reshape img_size . byteStringToVector . BS.drop 16  -- 16-byte header

-- reads the file and creates a labeled data
readData :: String -> String -> IO LabeledData
readData imgfile labelfile = do
    imgData <- makeImgData <$> decompress <$> BS.readFile imgfile
    labelData <- makeLabelData <$> decompress <$> BS.readFile labelfile
    return $ LabeledData imgData labelData

readMnist :: IO Mnist
readMnist = do
    trainDataset <- readData "train-images-idx3-ubyte.gz" "train-labels-idx1-ubyte.gz"
    testDataset <- readData "t10k-images-idx3-ubyte.gz" "t10k-labels-idx1-ubyte.gz"
    return $ Mnist trainDataset testDataset

-- ByteString is an optimized representation of Word8.
-- BS.readFile :: FilePath -> IO ByteString
-- decompress :: ByteString -> ByteString
readMnistAndShow :: IO ()
readMnistAndShow = do
  imgData <- makeImgData <$> decompress <$> BS.readFile "train-images-idx3-ubyte.gz"
  labelData <- makeLabelData <$> decompress <$> BS.readFile "train-labels-idx1-ubyte.gz"
  putStrLn $ show $ labelData
