import System.Environment
import System.Directory
import System.IO
import Control.Monad
import Data.Char
import Data.Ratio
import Data.List
import Data.List.Split
import Data.Maybe

-- Global constant
fileName = "recipes"

data Ingredient = Ingredient { quantity :: Ratio Int
                             , unit :: String
                             , ingredientName :: String
                             , attribute :: String
                             } deriving (Eq, Show, Read)

data Recipe = Recipe { recipeName :: String
                     , description :: String
                     , ingredients :: [Ingredient]
                     , directions :: [String]
                     , tags :: [String]
                     } deriving (Eq, Show, Read)

showFrac :: Ratio Int -> String
showFrac x
  | numerator x == denominator x = show (numerator x)
  | denominator x == 1 = show (numerator x)
  | whole > 0 = show whole ++ " " ++  showFrac (x - (fromIntegral whole))
  | otherwise = show (numerator x) ++ "/" ++ show (denominator x)
  where whole = floor $ fromIntegral (numerator x) / fromIntegral (denominator x)

readFrac :: String -> Ratio Int
readFrac x
  | ' ' `elem` x = let xs = splitOn " " x in ((read' (head xs)) % 1) + (readFrac (last xs))
  | '/' `elem` x = let xs = splitOn "/" x in (read' (head xs)) % (read' (last xs))
  | otherwise = (read x :: Int) % 1
  where read' = read :: String -> Int

getRecipeBook :: IO ([Recipe])
getRecipeBook = do
  contents <- readFile fileName
  return $ map read $ lines contents

getRecipe :: String -> [Recipe] -> Maybe Recipe
getRecipe target = listToMaybe . filter ((target ==) . recipeName)

add :: [String] -> IO ()
add _ = do
  putStrLn "Recipe name:"
  recpName <- getLine
  putStrLn "\nDescription:"
  recpDesc <- getLine
  putStrLn "\nNumber of ingredients:"
  numIngrs <- getLine
  let n = (read::String->Int) numIngrs
  ingrs <- forM [1..n] (\a -> do
    putStrLn $ "\nEnter amount for ingredient " ++ show a ++ " (e.g., 8 grams).\nPress enter if no specific amount desired:"
    amount <- getLine
    putStrLn $ "\nEnter name for ingredient " ++ show a ++ " (e.g., onion):"
    ingrName <- getLine
    putStrLn $ "\nEnter attribute for ingredient " ++ show a ++ " (e.g., chopped).\nPress enter if no attribute desired:"
    attr <- getLine
    let am = words amount
    if not (null am)
      then return Ingredient { quantity = readFrac (head am), unit = unwords (tail am), ingredientName = ingrName, attribute = attr }
    else return Ingredient { quantity = 0 % 1, unit = "", ingredientName = ingrName, attribute = attr })
  putStrLn "\nNumber of steps:"
  numSteps <- getLine
  let s = (read::String->Int) numSteps
  steps <- forM [1..s] (\a -> do
  putStrLn $ "\nEnter step " ++ show a ++ ":"
  getLine)
  putStrLn "\nEnter recipe tags separated by spaces (e.g., pasta Italian savory)"
  t <- getLine
  let newRecipe = Recipe { recipeName = recpName, description = recpDesc, ingredients = ingrs, directions = steps, tags = words t }
  appendFile fileName (show newRecipe ++ "\n")
  putStrLn ""
  putStrLn $ showRecipe newRecipe
  putStrLn "Added recipe!"

showIngredient :: Ingredient -> String
showIngredient i = qty ++ u ++ (ingredientName i) ++ att
  where qty = if quantity i == 0 then "" else showFrac (quantity i) ++ " "
        u   = if null (unit i) then "" else (unit i) ++ " "
        att = if null (attribute i) then "" else ", " ++ (attribute i)

showRecipe :: Recipe -> String
showRecipe r =  "+--" ++ filler ++ "+\n"
                ++ "|  " ++ recipeName r ++ "  |\n"
                ++ "+--" ++ filler ++ "+\n"
                ++ "\n" ++ description r ++ "\n"
                ++ "\nIngredients:\n"
                ++ unlines (zipWith (\a b -> a ++ b) (repeat "* ") $ map showIngredient $ ingredients r)
                ++ "\n" ++ unlines (zipWith (\i d -> "(" ++ show i ++ ") " ++ d) [1..] (directions r))
                where filler = take ((length $ recipeName r) + 2) $ repeat '-'

view :: [String] -> IO ()
view targets = do
  recipeBook <- getRecipeBook
  forM_ targets $ \ target -> do
    putStr $ case getRecipe target recipeBook of
      Nothing   -> target ++ " does not exist\n"
      Just recp -> showRecipe recp

list :: [String] -> IO ()
list _  = do
  recipes <- getRecipeBook
  let recipeList = map recipeName recipes
  putStr $ unlines recipeList

remove :: [String] -> IO ()
remove targets = forM_ targets $ \ target -> do
  recipeBook <- getRecipeBook
  (tempName, tempHandle) <- openTempFile "." "herms_temp"
  let (Just recp) = getRecipe target recipeBook
      newRecpBook = delete recp recipeBook
  putStrLn $ "Removing recipe: " ++ recipeName recp ++ "..."
  hPutStr tempHandle $ unlines $ show <$> newRecpBook
  hClose tempHandle
  removeFile fileName
  renameFile tempName fileName
  putStrLn "Recipe deleted."


help :: [String] -> IO ()
help _ = putStr $ unlines [ "Usage:"
                         , "./herms list                  - list recipes"
                         , "./herms view \"Recipe Name\"    - view a particular recipe"
                         , "./herms add                   - add a new recipe (interactive)"
                         , "./herms remove \"Recipe Name\"  - remove a particular recipe"
                         , "./herms help                  - display this help"
                         ]

dispatch :: [(String, [String] -> IO ())]
dispatch = [ ("add", add)
           , ("view", view)
           , ("remove", remove)
           , ("list", list)
           , ("help", help)
           ]

herms :: [String]      -- command line arguments
      -> Maybe (IO ()) -- failure or resulting IO action
herms args = do
  guard (not $ null args)
  action <- lookup (head args) dispatch
  return $ action (tail args)

main :: IO ()
main = do
  testCmd <- getArgs
  case herms testCmd of
    Nothing -> help [""]
    Just io -> io
