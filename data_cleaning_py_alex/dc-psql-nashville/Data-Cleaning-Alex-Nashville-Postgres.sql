------------------------------------------------------

-- 1. TABLE CREATION AND LOADING DATA

-------------------------------------------------------

DROP TABLE IF EXISTS nashville;

--Alex used Microsoft SQL Server, but i choose to do this data cleaning with Postgres SQL. So expect some changes to the way data is executed, but workflow still the same with same Nashville dataset.
--Compare to our SQL ,Postgres is super strict about datatype, marking everything as text is lazy way to get around it. You should always assign datatype to it. 
-- After creating table, header of table need to be created with its datatype. This process is whole lot more seamless in other SQL.
-- 1 trick that i use to quickly grab all header is by open csv with notepad, copy all header, and paste it into Chatgpt, or Gemini to make it formatted correctly.

CREATE TABLE nashville (
    UniqueID TEXT PRIMARY KEY,
    ParcelID TEXT,
    LandUse TEXT,
    PropertyAddress TEXT,
    SaleDate TEXT,
    SalePrice TEXT,
    LegalReference TEXT,
    SoldAsVacant TEXT,
    OwnerName TEXT,
    OwnerAddress TEXT,
    Acreage TEXT,
    TaxDistrict TEXT,
    LandValue TEXT,
    BuildingValue TEXT,
    TotalValue TEXT,
    YearBuilt TEXT,
    Bedrooms TEXT,
    FullBath TEXT,
    HalfBath TEXT
);

-- if you want to alter data type; below is example to integer.

ALTER TABLE Nashville 
ALTER COLUMN Bedrooms TYPE INT 
USING Bedrooms::INTEGER;
-------------------------

--Make sure folder in public folder. Find public folder by "Window + R" , type %public%. Store project folder there. 
--You can store it your own private folder, but you need to allow for client side using psql terminal. That is whole different nuisance hard get around. 
--Since i have Postgre and working folder both in my own computer, so this is ok. 
--This is for server side, SQL query only. 
--This command is essentially the "Import Wizard" of the command line. It’s telling PostgreSQL to grab data from a file on your computer and shove it into a table in your database.
-- Do not copy directly , edit path to folder.

COPY Nashville 
FROM 'C:\Users\Public\Documents\My Postgres\Data cleaning Nashvillle\Nashville Housing Data for Data Cleaning.csv' 
WITH (FORMAT csv, HEADER true);


-------------------------------------------------------

--2. Set date to standard

-------------------------------------------------------

-- I am following Alex flow, so first he set date as standard DD-MM-YYYYY
-- First i need to know current format i have for date

SHOW DateStyle;

-- So, i know it is a wrong style, so i set it.

SET DateStyle = 'SQL, DMY';


---After fix default date style, i alter column

ALTER TABLE Nashville 
ALTER COLUMN SaleDate TYPE DATE 
USING SaleDate::DATE;

-------------------------------------------------------

--3 Search null value by columns and fill it.

-------------------------------------------------------

-- next, i identify columns with null value. Postgres doesnt have a wide table search for null value, so you have to search it column by column

SELECT 
        COUNT(*) - COUNT(UniqueID) AS UniqueID,
        COUNT(*) - COUNT(ParcelID) AS ParcelID,
        COUNT(*) - COUNT(LandUse) AS LandUse,
        COUNT(*) - COUNT(PropertyAddress) AS PropertyAddress,
        COUNT(*) - COUNT(SaleDate) AS SaleDate,
        COUNT(*) - COUNT(SalePrice) AS SalePrice,
        COUNT(*) - COUNT(LegalReference) AS LegalReference,
        COUNT(*) - COUNT(SoldAsVacant) AS SoldAsVacant,
        COUNT(*) - COUNT(OwnerName) AS OwnerName,
        COUNT(*) - COUNT(OwnerAddress) AS OwnerAddress,
        COUNT(*) - COUNT(Acreage) AS Acreage,
        COUNT(*) - COUNT(TaxDistrict) AS TaxDistrict,
        COUNT(*) - COUNT(LandValue) AS LandValue,
        COUNT(*) - COUNT(BuildingValue) AS BuildingValue,
        COUNT(*) - COUNT(TotalValue) AS TotalValue,
        COUNT(*) - COUNT(YearBuilt) AS YearBuilt,
        COUNT(*) - COUNT(Bedrooms) AS Bedrooms,
        COUNT(*) - COUNT(FullBath) AS FullBath,
        COUNT(*) - COUNT(HalfBath) AS HalfBath
    FROM Nashville;

-- this code find different between count of all rows minus count of rows with value.
-- this will open a table. any column not zero has null value. now up to use on how to handle the null.
-- they are elegant way of doing this, like doing cross join lateral to create list of column with number of null value.
-- from table, we can see first column with nullvalue is PropertyAddress
-- lets populate PropertyAddress

SELECT * FROM nashville 
WHERE propertyaddress IS NULL;

-- roughly , from table we can see some have propertyaddress is correspond to one parcelid.but some are not?
-- lets verify it

SELECT 
    ParcelID, 
    COUNT(DISTINCT PropertyAddress) AS UniqueAddressCount
FROM  Nashville
WHERE PropertyAddress IS NOT NULL
GROUP BY ParcelID
HAVING COUNT(DISTINCT PropertyAddress) > 1;

-- so this code is to count how many address associated with one parcelid, turns out 1 parcelid is not necessarily match with 1 address,

WITH count_query as (SELECT 
    ParcelID, 
    COUNT(DISTINCT PropertyAddress) AS UniqueAddressCount
FROM  Nashville
WHERE PropertyAddress IS NOT NULL
GROUP BY ParcelID
)

SELECT 
	UniqueAddressCount ,
	COUNT(*) AS Num,
FROM count_query
GROUP BY UniqueAddressCount
ORDER BY UniqueAddressCount;

--so this code is using cte to count uniqueaddresscount per parcelid. 

/* output 

1	46518
2	2032
3	9

*/

-- 46518 is large enough to make assumption of 1 parcelid to 1 propertyaddress , to fill null value of propertyaddress
-- so we update table

UPDATE Nashville AS a
SET PropertyAddress = b.PropertyAddress
FROM Nashville AS b
WHERE a.ParcelID = b.ParcelID
  AND a.PropertyAddress IS NULL
  AND b.PropertyAddress IS NOT NULL;

---to verify if its works

SELECT COUNT(*) 
FROM Nashville 
WHERE PropertyAddress IS NULL;

-------------------------------------------------------

--4. Breaking Property Address into 2 column

-------------------------------------------------------

-- from propertyaddress , there is only one comma, can we split this into two, before comma it was house no and street, and
-- the 2nd part is city.

SELECT 
    PropertyAddress,
    SPLIT_PART(PropertyAddress, ',', 1) AS Street, 
    TRIM(SPLIT_PART(PropertyAddress, ',', 2)) AS City 
FROM Nashville;

-- Altering table to add new column

ALTER TABLE Nashville
ADD COLUMN PropertySplitAddress VARCHAR(255),
ADD COLUMN PropertySplitCity VARCHAR(255);

-- Update new empty column 

UPDATE Nashville
SET PropertySplitAddress = SPLIT_PART(PropertyAddress, ',', 1),
    PropertySplitCity = TRIM(SPLIT_PART(PropertyAddress, ',', 2));

-------------------------------------------------------

--5. Standardize 'soldasvacant' 'yes or no' 

-------------------------------------------------------

SELECT DISTINCT(soldasvacant) FROM nashville ;

--This code will show there are 4 options for yes or no; y,n, yes,no. So we need to convert y to yes and n to no

UPDATE Nashville
SET SoldAsVacant = CASE 
    WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant -- This keeps 'Yes' and 'No' exactly as they are
END;

-- Done, verify with this code

SELECT DISTINCT(soldasvacant) FROM nashville  ;

-- We should have 2 value only.

-------------------------------------------------------

--6. Remove duplicates

-------------------------------------------------------

-- so we search for any rows with duplicate where all 5 columns is the same, it will be numbered as 2.

WITH rownumCTE AS (SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY
				parcelid,
				propertyaddress,
				saledate,
				legalreference
				ORDER BY uniqueid
				) as row_num
FROM nashville
)

SELECT * FROM rownumCTE 
where row_num > 1;

-- we can see there are 104 rows are duplicate.
-- so we delete them
-- postgres can directly delete from cte, so we need to use uniqueid to identify which row

WITH RowNumCTE AS (
    SELECT 
        uniqueid, -- We need this to identify the specific row to delete
        ROW_NUMBER() OVER (
            PARTITION BY 
                parcelid,
                propertyaddress,
                saledate,
                legalreference
            ORDER BY uniqueid
        ) as row_num
    FROM nashville
)
DELETE FROM nashville
WHERE uniqueid IN (
    SELECT uniqueid 
    FROM RowNumCTE 
    WHERE row_num > 1
);


--all duplicated rows are deleted.

-------------------------------------------------------

--7. Drop unused columns

-------------------------------------------------------

-- usually, dropping unused columns is the last thing we do for cleaning data into production
-- below is code

ALTER TABLE Nashville
DROP COLUMN IF EXISTS TaxDistrict,
DROP COLUMN IF EXISTS OwnerAddress;

--FINISH!!
