SELECT * 
FROM FirstProject.dbo.NashvilleHousing

--Checking for values different than No and Yes
SELECT SoldAsVacant, COUNT(*)
FROM FirstProject.dbo.NashvilleHousing
GROUP BY SoldAsVacant

-- Replace N and Y with No and Yes
BEGIN TRANSACTION
UPDATE NashvilleHousing
SET SoldAsVacant = 
	(CASE WHEN SoldAsVacant = 'N' THEN 'NO'
		  WHEN SoldAsVacant = 'Y' THEN 'YES' 
		  ELSE SoldAsVacant END)
ROLLBACK TRANSACTION
	

--Checking date format
SELECT SaleDate, CONVERT(Date, SaleDate), CONVERT(VARCHAR(10), SaleDate, 120)
FROM FirstProject.dbo.NashvilleHousing

--None of the below updates the table
--To be investigated further
UPDATE NashvilleHousing
SET SaleDate = CONVERT(Date, SaleDate)

UPDATE NashvilleHousing
SET SaleDate = CAST(SaleDate AS DATE)

UPDATE NashvilleHousing
SET SaleDate = CONVERT(VARCHAR(10), SaleDate, 101)

UPDATE NashvilleHousing
SET SaleDate = LEFT(SaleDate,12)

--Only way that works
ALTER TABLE NashvilleHousing
ADD SaleDateConverted Date

UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(Date, SaleDate)

--Confirming changes
SELECT SaleDate, SaleDateConverted
FROM FirstProject.dbo.NashvilleHousing

ALTER TABLE NashvilleHousing
DROP COLUMN SaleDate

--Cleaning PropertyAddress by comparing it with Parcel ID
--We notice that ParcelID is linked to PropertyAddress
SELECT ParcelID, PropertyAddress
FROM FirstProject.dbo.NashvilleHousing
--WHERE PropertyAddress IS NULL
ORDER BY 1, 2

--Returns 
SELECT a.ParcelID, a.PropertyAddress, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress) AS CorrectedAddress
FROM FirstProject.dbo.NashvilleHousing a
JOIN FirstProject.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL --Returns nothing after we run the UPDATE below

--Replace NULL values in PropertyAddress
BEGIN TRANSACTION
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM FirstProject.dbo.NashvilleHousing a
JOIN FirstProject.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL
ROLLBACK TRANSACTION

--Confirming NULL replaced with correct address
SELECT COUNT(*)
FROM NashvilleHousing
WHERE PropertyAddress IS NULL


--Seperating PropertyAddress where we have comma

SELECT 
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) As Address, 
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) as City
FROM FirstProject.dbo.NashvilleHousing

ALTER TABLE NashvilleHousing
ADD PropertyCleanAddress VARCHAR(255), PropertyCleanCity VARCHAR(255)

UPDATE NashvilleHousing
SET PropertyCleanAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1), PropertyCleanCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress))


--Cleaning OwnerAddress
SELECT OwnerAddress
FROM FirstProject.dbo.NashvilleHousing

SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.'),3),
PARSENAME(REPLACE(OwnerAddress, ',', '.'),2),
PARSENAME(REPLACE(OwnerAddress, ',', '.'),1)
FROM FirstProject.dbo.NashvilleHousing

ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress VARCHAR(255), OwnerSplitCity VARCHAR(255), OwnerSplitState VARCHAR(255)

UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'),3), 
OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'),2),
OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'),1)


-- Confirming 
SELECT COUNT(*) - (SELECT COUNT(*) FROM FirstProject.dbo.NashvilleHousing 
WHERE PropertyAddress = CONCAT(OwnerSplitAddress, ',', OwnerSplitCity)), 
COUNT(*) - COUNT(OwnerSplitAddress) AS OwAdd, 
COUNT(*) - COUNT(OwnerSplitCity) AS OwCity
FROM FirstProject.dbo.NashvilleHousing
--WHERE PropertyAddress = CONCAT(OwnerSplitAddress, ',', OwnerSplitCity)

SELECT COUNT(*)
FROM FirstProject.dbo.NashvilleHousing
WHERE OwnerAddress IS NULL

SELECT COUNT(*) - COUNT(OwnerAddress) AS OwnerAddressNULL, 
COUNT(*) - COUNT(OwnerSplitCity) AS OwnerSplitCityNULL,
(SELECT COUNT(*)
FROM FirstProject.dbo.NashvilleHousing
WHERE PropertyAddress = CONCAT(OwnerSplitAddress, ',', OwnerSplitCity)) AS NEW
FROM FirstProject.dbo.NashvilleHousing

--Checking duplicates between owneraddress and property address
SELECT CONCAT(OwnerSplitAddress,' ', OwnerSplitCity), PropertyAddress, ROW_NUMBER() OVER (
PARTITION BY OwnerAddress, 
			 PropertyAddress
			 ORDER BY PropertyAddress) as tst
FROM FirstProject.dbo.NashvilleHousing

SELECT * FROM FirstProject.dbo.NashvilleHousing
ORDER BY OwnerName

--By running the below query I noticed that some addresses have double spaces
SELECT OwnerAddress, PropertyAddress,CONCAT(OwnerSplitAddress, ',', OwnerSplitCity), LEN(CONCAT(OwnerSplitAddress, ',', OwnerSplitCity)), LEN(PropertyAddress)
FROM FirstProject.dbo.NashvilleHousing
WHERE PropertyAddress != CONCAT(OwnerSplitAddress, ',', OwnerSplitCity)

--Removing double spaces
UPDATE NashvilleHousing
SET OwnerSplitAddress = REPLACE(OwnerSplitAddress, '  ', ' '),
	OwnerSplitCity = REPLACE(OwnerSplitCity, '  ', ' '),
	OwnerSplitState = REPLACE(OwnerSplitState, '  ', ' '),
	PropertyAddress = REPLACE(PropertyAddress, '  ', ' ')

--After running above query we can clearly see that in some cases OwnerAddress does not match Property Address
--Therefore we won't replace NULL values in OwnerAddress


--Checking duplicated rows, sharing different UniqueID
--Use of CTE
WITH RowNumCTE AS(
SELECT *, 
ROW_NUMBER() OVER (PARTITION BY ParcelID, 
								PropertyAddress, 
								SalePrice, 
								SaleDateConverted, 
								LegalReference 
								ORDER BY UniqueID) row_num
FROM FirstProject.dbo.NashvilleHousing)
SELECT *
FROM RowNumCTE
WHERE row_num > 1

--Deleting the duplicated rows
WITH RowNumCTE AS(
SELECT *, 
ROW_NUMBER() OVER (PARTITION BY ParcelID, 
								PropertyAddress, 
								SalePrice, 
								SaleDateConverted, 
								LegalReference 
								ORDER BY UniqueID) row_num
FROM FirstProject.dbo.NashvilleHousing)
DELETE 
FROM RowNumCTE
WHERE row_num > 1