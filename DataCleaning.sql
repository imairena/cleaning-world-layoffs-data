 -- Data Cleaning Project
 
 -- GENERAL NOTE: I was not able to identify the "Preferences" tab where I could turn off safe mode
 -- so throughout the data cleaning process I manually turned it off and added appropriate documentation.
 
SELECT *
FROM layoffs;

-- Goals:
-- 1. Remove Duplicates
-- 2. Standardize the Data (e.g. United States / US -> US)
-- 3. NULL or blank values
-- 4. Remove Any Columns (=> Need to create new table)

-- ------------------------------------- SETUP -----------------------------------------------
-- Creating new table
CREATE TABLE layoffs_staging
LIKE layoffs;

-- Checking out new table (column names)
SELECT *
FROM layoffs_staging;

-- Inserting the data into the new table and viewing it
INSERT layoffs_staging
SELECT *
FROM layoffs;

-- ------------------------------------- REMOVING DUPLICATES ---------------------------------
-- Identifying identical rows and viewing them using a CTE
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
 `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- We will create a new table called 'layoffs-staging2' with an additional column "rows"
-- then delete the rows from the table. The reason for this is that we cannot update a CTE
-- i.e. we cannot use the DELETE keyword for a CTE

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num`INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Checking that the columns were all added properly
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;
-- Inserting the data into the new table
INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
 `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;
-- Deleting duplicates
SET SQL_SAFE_UPDATES = 0; -- We turn off safe updates to delete entire table
DELETE
FROM layoffs_staging2
WHERE row_num > 1;
SET SQL_SAFE_UPDATES = 1; -- Turn on safe updates after deleting table for safety

-- Check data after duplicates have been removed
SELECT *
FROM layoffs_staging2;
-- Note that removing duplicates could have been done much faster if one of the columns
-- was unique. Then, we could have performed an inner join of table with itself and find
-- and delete rows that have the same data but larger id


-- ------------------------------------- STANDARDIZING DATA -----------------------------------
-- Check company names first
SELECT company, TRIM(company) -- Comparing for differences in whitespace
FROM layoffs_staging2;

SET SQL_SAFE_UPDATES = 0; -- Again, updating table so need to turn off safe mode
UPDATE layoffs_staging2
SET company = TRIM(company);
SET SQL_SAFE_UPDATES = 1;

-- Check industry
SELECT DISTINCT industry -- Checking if two or more industries appearing as different are meant to be the same (e.g Crypto and Crypto Currency)
FROM layoffs_staging2
ORDER BY 1; -- So it's more clear which industries are the same

SELECT * 
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%'; -- We want to see which industry name is more popular between Crypto and Crypto Currency

SET SQL_SAFE_UPDATES = 0; -- Updating industry so all crypto-like names just display "Crypto"
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';
SET SQL_SAFE_UPDATES = 1;

-- Check country
SELECT DISTINCT country -- Problem: "United States" vs "United States.". Eveything else looks good
FROM layoffs_staging2
ORDER BY 1;

SELECT * 
FROM layoffs_staging2
WHERE country LIKE 'United States%'; -- As expected, "United States" is the more common response

SET SQL_SAFE_UPDATES = 0; -- Updating country
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country) -- Removes trailing period from "United States." in this case
WHERE country LIKE 'United States%';
SET SQL_SAFE_UPDATES = 1;

-- Check date
-- Date was originally imported as text which is useless if we want to do time series analysis. Thus we turn it into datetime format
SELECT `date`
FROM layoffs_staging2;

-- Update date to datetime
SET SQL_SAFE_UPDATES = 0; -- Updating date. Note that the column is still considered of type text
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y'); -- Turns strings into datetimes
SET SQL_SAFE_UPDATES = 1;

-- Changing column type
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Check changes
SELECT *
FROM layoffs_staging2;
DESCRIBE layoffs_staging2; -- Notice how date column is now of type date


-- ------------------------------ REMOVING NULL AND BLANK VALUES -------------------------------
-- checking total_laid_off
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL; -- if both data fields are NULL, then the row is useless in this case

-- checking industry
-- Make blanks NULL for simplicity
SET SQL_SAFE_UPDATES = 0; -- Updating industry
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';
SET SQL_SAFE_UPDATES = 1;


SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;

-- Now we will join this table with itself so that entries in the left table with a NULL industry
-- can be filled with the correct industry from another entry with a filled industry field from the right table
SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging t2
ON t1.company = t2.company
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL
AND t2.industry != '';;

SET SQL_SAFE_UPDATES = 0; -- Turning the command above into an update statement to actually make changes
UPDATE layoffs_staging2 t1
JOIN layoffs_staging t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL
AND t2.industry != '';;
SET SQL_SAFE_UPDATES = 1;

-- Rows that still have NULL as the industry field may need to be deleted since there is no way to know what industry they belong to
-- unless we google them

-- Also note that things like total_laid_off, percentage_laid_off, funds_raised_millions, are data that we do not have a way to fill in 
-- (especially funds_raised_millions). If we were given a total_employees column we could do some math to calculate total and percentage laid off


-- ------------------------------ DELETING UNNECESSARY COLUMNS ---------------------------------------
-- columns where both total and percentage laid off are NULL
SET SQL_SAFE_UPDATES = 0;
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
SET SQL_SAFE_UPDATES = 1;

SELECT * -- checking the update was done properly
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;


-- deleting entire row_num column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT * -- checking the update was done properly (This is the cleaned data)
FROM layoffs_staging2;


























